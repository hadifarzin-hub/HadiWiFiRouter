param()
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$AppDir=Split-Path -Parent $MyInvocation.MyCommand.Path
$Root=Split-Path -Parent $AppDir
$EngineDir=Join-Path $AppDir 'packetengine'
$RulesFile=Join-Path $EngineDir 'rules.txt'
$Cfg=Join-Path $AppDir 'config.json'
$Log=Join-Path $Root 'logs\packetengine.log'
New-Item -ItemType Directory -Force -Path (Split-Path $Log -Parent) | Out-Null
function Log([string]$m){ Add-Content -Path $Log -Value ("{0:u} {1}" -f (Get-Date),$m) -Encoding UTF8 }
if(-not (Test-Path (Join-Path $EngineDir 'WinDivert.dll'))){ Log 'ERROR WinDivert.dll missing. Run Setup-Packet-Engine.cmd.'; exit 2 }
if(-not (Test-Path (Join-Path $EngineDir 'WinDivert64.sys'))){ Log 'ERROR WinDivert64.sys missing. Run Setup-Packet-Engine.cmd.'; exit 2 }

try {
    . (Join-Path $AppDir 'WebsiteRules.ps1')
    if(Test-Path $Cfg){ $c=Get-Content $Cfg -Raw -Encoding UTF8 | ConvertFrom-Json; [void](Write-PacketEngineRules $c) }
} catch { Log ('WARNING initial rules generation failed: '+$_.Exception.Message) }

$subnet='192.168.137.0/24'
try { if($null -ne $c -and $null -ne $c.PSObject.Properties['HotspotSubnet']){$subnet=[string]$c.HotspotSubnet} } catch {}
$prefix=($subnet -replace '\.0/24$','.')
if($prefix -eq $subnet){$prefix='192.168.137.'}

$src=@'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using System.IO;
using System.Net;

public static class HadiDnsFilter {
    const int NETWORK=0, FORWARD=1;
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool SetDllDirectory(string path);
    [DllImport("WinDivert.dll", CallingConvention=CallingConvention.Cdecl, SetLastError=true)] static extern IntPtr WinDivertOpen([MarshalAs(UnmanagedType.LPStr)] string filter,int layer,short priority,ulong flags);
    [DllImport("WinDivert.dll", CallingConvention=CallingConvention.Cdecl, SetLastError=true)] static extern bool WinDivertRecv(IntPtr h, byte[] packet,uint packetLen,out uint recvLen,IntPtr addr);
    [DllImport("WinDivert.dll", CallingConvention=CallingConvention.Cdecl, SetLastError=true)] static extern bool WinDivertSend(IntPtr h, byte[] packet,uint packetLen,out uint sendLen,IntPtr addr);
    [DllImport("WinDivert.dll", CallingConvention=CallingConvention.Cdecl, SetLastError=true)] static extern bool WinDivertClose(IntPtr h);

    static HashSet<string> blocked=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
    static HashSet<uint> blockedIPv4=new HashSet<uint>();
    static bool enabled=false, strictNative=false;
    static string prefix, logPath, rulesPath;
    static object stateLock=new object(), logLock=new object();
    static long lastRulesTicks=-1;

    static void Log(string m){ try{ lock(logLock){ File.AppendAllText(logPath,DateTime.UtcNow.ToString("u")+" "+m+Environment.NewLine,Encoding.UTF8); } }catch{} }

    static uint ToUInt32(IPAddress ip){
        byte[] b=ip.GetAddressBytes();
        if(b.Length!=4) return 0;
        return ((uint)b[0]<<24)|((uint)b[1]<<16)|((uint)b[2]<<8)|b[3];
    }

    static HashSet<uint> ResolveBlockedIps(HashSet<string> domains){
        var ips=new HashSet<uint>();
        foreach(string d in domains){
            if(d.IndexOf('*')>=0) continue;
            try{
                foreach(var ip in Dns.GetHostAddresses(d)){
                    if(ip.AddressFamily==System.Net.Sockets.AddressFamily.InterNetwork){ uint u=ToUInt32(ip); if(u!=0) ips.Add(u); }
                }
            }catch(Exception ex){ Log("RESOLVE WARNING "+d+" "+ex.Message); }
        }
        return ips;
    }

    static void LearnBlockedName(string name){
        // Native apps frequently use dynamic host names and TLS ECH, which can hide SNI.
        // When we see a blocked DNS query, resolve that concrete hostname ourselves and
        // immediately add its current IPv4 destinations to the live drop table.
        // This also catches already-cached/native-app sessions on subsequent packets.
        try{
            int added=0;
            foreach(var ip in Dns.GetHostAddresses(name)){
                if(ip.AddressFamily!=System.Net.Sockets.AddressFamily.InterNetwork) continue;
                uint u=ToUInt32(ip); if(u==0) continue;
                lock(stateLock){ if(blockedIPv4.Add(u)) added++; }
                if(added>0) Log("LEARN IP "+name+" -> "+ip.ToString());
            }
        }catch(Exception ex){ Log("LEARN WARNING "+name+" "+ex.Message); }
    }

    static void ReloadRulesIfNeeded(bool force){
        try{
            if(!File.Exists(rulesPath)){
                lock(stateLock){ enabled=false; blocked.Clear(); blockedIPv4.Clear(); }
                return;
            }
            long t=File.GetLastWriteTimeUtc(rulesPath).Ticks;
            if(!force && t==Interlocked.Read(ref lastRulesTicks)) return;
            string[] lines=File.ReadAllLines(rulesPath,Encoding.UTF8);
            bool en=false, sn=false; var next=new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach(string raw in lines){
                string s=(raw??"").Trim(); if(s.Length==0) continue;
                if(s.StartsWith("enabled=",StringComparison.OrdinalIgnoreCase)){ en=s.EndsWith("1"); continue; }
                if(s.StartsWith("strictnative=",StringComparison.OrdinalIgnoreCase)){ sn=s.EndsWith("1"); continue; }
                next.Add(s.Trim('.').ToLowerInvariant());
            }
            var nextIps=en ? ResolveBlockedIps(next) : new HashSet<uint>();
            lock(stateLock){ enabled=en; strictNative=sn; blocked=next; blockedIPv4=nextIps; }
            Interlocked.Exchange(ref lastRulesTicks,t);
            Log("RULES RELOADED enabled="+en+" strictNative="+sn+" domains="+next.Count+" resolvedIPv4="+nextIps.Count);
        }catch(Exception ex){ Log("RULE RELOAD ERROR "+ex.Message); }
    }

    public static void Run(string dllDir,string clientPrefix,string lp,string rp){
        SetDllDirectory(dllDir); prefix=clientPrefix; logPath=lp; rulesPath=rp; ReloadRulesIfNeeded(true);

        // Dedicated watcher: rules are reloaded even when the phone is using cached DNS and makes no new DNS request.
        var watcher=new Thread(()=>{
            while(true){ ReloadRulesIfNeeded(false); Thread.Sleep(500); }
        }); watcher.IsBackground=true; watcher.Start();

        var t1=new Thread(()=>DnsLoop(NETWORK,"udp.DstPort == 53 or tcp.DstPort == 53")); t1.IsBackground=false; t1.Start();
        var t2=new Thread(()=>DnsLoop(FORWARD,"udp.DstPort == 53 or tcp.DstPort == 53")); t2.IsBackground=false; t2.Start();

        // Drop packets from hotspot clients to IPs that belong to newly blocked domains.
        // This makes re-blocking take effect for existing/cached sessions instead of waiting for DNS cache expiry.
        var t3=new Thread(()=>TrafficLoop(NETWORK,"ip")); t3.IsBackground=false; t3.Start();
        var t4=new Thread(()=>TrafficLoop(FORWARD,"ip")); t4.IsBackground=false; t4.Start();
        // iOS strongly prefers IPv6 when available. The v2.0 engine only parsed IPv4, which left a bypass path for native apps.
        // In strict native-app mode we drop forwarded IPv6 (not PC-originated traffic), forcing hotspot clients onto the inspected IPv4 path.
        var t5=new Thread(()=>Ipv6ForwardLoop()); t5.IsBackground=false; t5.Start();

        Log("Packet engine v2.2 active: DNS + TLS-SNI + QUIC/DoT suppression + forwarded-IPv6 fallback protection + cached-session IP enforcement. Client prefix="+prefix);
        t1.Join(); t2.Join(); t3.Join(); t4.Join(); t5.Join();
    }

    static void DnsLoop(int layer,string filter){
        IntPtr h=WinDivertOpen(filter,layer,0,0);
        if(h==new IntPtr(-1)){ Log("WinDivertOpen DNS failed layer="+layer+" error="+Marshal.GetLastWin32Error()); return; }
        byte[] pkt=new byte[65535]; IntPtr addr=Marshal.AllocHGlobal(80);
        try{
            while(true){
                uint len; if(!WinDivertRecv(h,pkt,(uint)pkt.Length,out len,addr)) continue;
                bool drop=false; try{ drop=ShouldBlockDns(pkt,(int)len); }catch(Exception ex){Log("DNS PARSE ERROR "+ex.Message);} 
                if(drop) continue;
                uint sent; WinDivertSend(h,pkt,len,out sent,addr);
            }
        } finally { Marshal.FreeHGlobal(addr); WinDivertClose(h); }
    }

    static void TrafficLoop(int layer,string filter){
        IntPtr h=WinDivertOpen(filter,layer,10,0);
        if(h==new IntPtr(-1)){ Log("WinDivertOpen TRAFFIC failed layer="+layer+" error="+Marshal.GetLastWin32Error()); return; }
        byte[] pkt=new byte[65535]; IntPtr addr=Marshal.AllocHGlobal(80);
        try{
            while(true){
                uint len; if(!WinDivertRecv(h,pkt,(uint)pkt.Length,out len,addr)) continue;
                bool drop=false; try{ drop=ShouldBlockDestination(pkt,(int)len); }catch(Exception ex){Log("TRAFFIC PARSE ERROR "+ex.Message);} 
                if(drop) continue;
                uint sent; WinDivertSend(h,pkt,len,out sent,addr);
            }
        } finally { Marshal.FreeHGlobal(addr); WinDivertClose(h); }
    }

    static void Ipv6ForwardLoop(){
        IntPtr h=WinDivertOpen("ipv6",FORWARD,20,0);
        if(h==new IntPtr(-1)){ Log("WinDivertOpen IPv6 FORWARD failed error="+Marshal.GetLastWin32Error()); return; }
        byte[] pkt=new byte[65535]; IntPtr addr=Marshal.AllocHGlobal(80);
        try{
            while(true){
                uint len; if(!WinDivertRecv(h,pkt,(uint)pkt.Length,out len,addr)) continue;
                bool drop=false; lock(stateLock){ drop=enabled && strictNative; }
                if(drop){ Log("BLOCK IPv6 FORWARD (strict native-app mode)"); continue; }
                uint sent; WinDivertSend(h,pkt,len,out sent,addr);
            }
        } finally { Marshal.FreeHGlobal(addr); WinDivertClose(h); }
    }

    static bool IsClient(byte[] p,int len){
        if(len<20 || ((p[0]>>4)&15)!=4) return false;
        string src=p[12]+"."+p[13]+"."+p[14]+"."+p[15];
        return src.StartsWith(prefix,StringComparison.Ordinal);
    }

    static bool WildcardMatch(string text,string pattern){
        text=text.ToLowerInvariant(); pattern=pattern.ToLowerInvariant();
        int ti=0, pi=0, star=-1, mark=-1;
        while(ti<text.Length){
            if(pi<pattern.Length && pattern[pi]==text[ti]){ti++;pi++;continue;}
            if(pi<pattern.Length && pattern[pi]=='*'){star=pi++;mark=ti;continue;}
            if(star!=-1){pi=star+1;ti=++mark;continue;}
            return false;
        }
        while(pi<pattern.Length && pattern[pi]=='*')pi++;
        return pi==pattern.Length;
    }

    static bool IsBlockedName(string name){
        lock(stateLock){
            if(!enabled) return false;
            foreach(string d in blocked){
                if(d.IndexOf('*')>=0){ if(WildcardMatch(name,d)) return true; }
                else if(name.Equals(d,StringComparison.OrdinalIgnoreCase)||name.EndsWith("."+d,StringComparison.OrdinalIgnoreCase)) return true;
            }
        }
        return false;
    }

    static string TryGetTlsSni(byte[] p,int len){
        try{
            if(len<40 || ((p[0]>>4)&15)!=4 || p[9]!=6) return null;
            int ihl=(p[0]&15)*4; if(len<ihl+20) return null;
            int tcp=ihl, dport=(p[tcp+2]<<8)|p[tcp+3]; if(dport!=443 && dport!=8443) return null;
            int thl=((p[tcp+12]>>4)&15)*4; int o=tcp+thl; if(thl<20 || o+9>=len) return null;
            if(p[o]!=22) return null; // TLS handshake record
            int recLen=(p[o+3]<<8)|p[o+4]; if(o+5+recLen>len) recLen=len-(o+5);
            int h=o+5; if(h+4>=len || p[h]!=1) return null; // ClientHello
            int x=h+4+2+32; if(x>=len) return null;
            int sid=p[x++]; x+=sid; if(x+2>len) return null;
            int cs=(p[x]<<8)|p[x+1]; x+=2+cs; if(x>=len) return null;
            int comp=p[x++]; x+=comp; if(x+2>len) return null;
            int extTotal=(p[x]<<8)|p[x+1]; x+=2; int end=Math.Min(len,x+extTotal);
            while(x+4<=end){
                int type=(p[x]<<8)|p[x+1], elen=(p[x+2]<<8)|p[x+3]; x+=4;
                if(x+elen>end) return null;
                if(type==0 && elen>=5){
                    int y=x; int listLen=(p[y]<<8)|p[y+1]; y+=2; int listEnd=Math.Min(x+elen,y+listLen);
                    while(y+3<=listEnd){ int nt=p[y++]; int nl=(p[y]<<8)|p[y+1]; y+=2; if(y+nl>listEnd)return null; if(nt==0)return Encoding.ASCII.GetString(p,y,nl).Trim('.').ToLowerInvariant(); y+=nl; }
                }
                x+=elen;
            }
        }catch{}
        return null;
    }

    static bool ShouldBlockDestination(byte[] p,int len){
        if(len<20 || ((p[0]>>4)&15)!=4 || !IsClient(p,len)) return false;
        int ihl=(p[0]&15)*4; int proto=p[9];
        bool sn=false; lock(stateLock){sn=enabled && strictNative;}
        if(sn && proto==17 && len>=ihl+8){
            int dport=(p[ihl+2]<<8)|p[ihl+3];
            if(dport==443){ return true; } // force native apps away from QUIC/HTTP3 so TLS SNI can be enforced
            if(dport==853){ Log("BLOCK DoT UDP from hotspot client"); return true; }
        }
        if(sn && proto==6 && len>=ihl+20){
            int dport=(p[ihl+2]<<8)|p[ihl+3];
            if(dport==853){ Log("BLOCK DoT TCP from hotspot client"); return true; }
        }
        if(proto==6){
            string sni=TryGetTlsSni(p,len);
            if(!String.IsNullOrEmpty(sni) && IsBlockedName(sni)){
                string src=p[12]+"."+p[13]+"."+p[14]+"."+p[15]; Log("BLOCK TLS-SNI "+src+" -> "+sni); return true;
            }
        }
        uint dst=((uint)p[16]<<24)|((uint)p[17]<<16)|((uint)p[18]<<8)|p[19];
        bool hit=false;
        lock(stateLock){ if(enabled && blockedIPv4.Contains(dst)) hit=true; }
        if(hit){
            string src=p[12]+"."+p[13]+"."+p[14]+"."+p[15];
            string dip=p[16]+"."+p[17]+"."+p[18]+"."+p[19];
            Log("BLOCK IP "+src+" -> "+dip);
            return true;
        }
        return false;
    }

    static bool ShouldBlockDns(byte[] p,int len){
        if(len<28 || !IsClient(p,len)) return false;
        int ihl=(p[0]&15)*4; if(ihl<20 || len<ihl+8) return false;
        string src=p[12]+"."+p[13]+"."+p[14]+"."+p[15];
        int proto=p[9], dns;
        if(proto==17){
            int udp=ihl; if(len<udp+8) return false; int dport=(p[udp+2]<<8)|p[udp+3]; if(dport!=53) return false; dns=udp+8;
        } else if(proto==6){
            int tcp=ihl; if(len<tcp+20) return false; int dport=(p[tcp+2]<<8)|p[tcp+3]; if(dport!=53) return false;
            int thl=((p[tcp+12]>>4)&15)*4; if(thl<20 || len<tcp+thl+2+12) return false; dns=tcp+thl+2;
        } else return false;
        if(len<dns+12) return false;
        int q=dns+12; if(q>=len) return false;
        StringBuilder sb=new StringBuilder();
        while(q<len){ int n=p[q++]; if(n==0) break; if((n&0xC0)!=0 || n>63 || q+n>len) return false; if(sb.Length>0) sb.Append('.'); sb.Append(Encoding.ASCII.GetString(p,q,n)); q+=n; }
        string name=sb.ToString().Trim('.').ToLowerInvariant(); if(name.Length==0) return false;
        if(IsBlockedName(name)){ LearnBlockedName(name); Log("BLOCK DNS "+src+" -> "+name); return true; }
        return false;
    }
}
'@
Add-Type -TypeDefinition $src -Language CSharp
Log 'Starting packet engine v2.2 (DNS/TLS-SNI/native-app enforcement + live reload).'
[HadiDnsFilter]::Run($EngineDir,$prefix,$Log,$RulesFile)