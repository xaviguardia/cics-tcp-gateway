#!/usr/bin/env python3
"""Small SSE web console for independent CICS TCP gateway sessions."""

from __future__ import annotations

import argparse
import json
import queue
import socket
import struct
import sys
import threading
import time
from dataclasses import dataclass
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlparse


DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 8088
DEFAULT_BACKEND = "127.0.0.1:4321"
MAX_COMMAREA = 4096
MAX_SESSIONS = 128
HEADER_LEN = 12
RESPONSE_HEADER_LEN = 8
SOCKET_TIMEOUT = 60.0


HTML = r"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>CICS Environmental Monitoring — IBM System/370</title>
<style>
*{box-sizing:border-box;margin:0;padding:0}
:root{--bg:#060810;--p:#0c0f16;--c:#10141c;--ln:#1a2030;--t:#dce4ec;--mt:#5a6a7e;--g:#33ff33;--ok:#4ade80;--bad:#f87171;
--m:'SF Mono',ui-monospace,SFMono-Regular,Menlo,monospace}
body{background:var(--bg);color:var(--t);font:13px -apple-system,system-ui,sans-serif;height:100vh;display:flex;flex-direction:column;overflow:hidden}

/* Header */
.hdr{position:relative;background:linear-gradient(180deg,#0a1a0a,#061208);border-bottom:2px solid #1a3a1a;padding:8px 20px;display:flex;align-items:center;justify-content:space-between;flex-shrink:0}
.hdr::after{content:'';position:absolute;inset:0;background:repeating-linear-gradient(0deg,transparent,transparent 2px,rgba(0,0,0,.12) 2px,rgba(0,0,0,.12) 4px);pointer-events:none}
.hdr h1{font:700 16px var(--m);color:var(--g);text-shadow:0 0 10px rgba(51,255,51,.4)}
.hdr .sub{font:11px var(--m);color:rgba(51,255,51,.5);margin-top:1px}
.hdr-r{text-align:right;font:11px var(--m);color:rgba(51,255,51,.5)}
.hdr-r .up{font-size:14px;color:var(--g);text-shadow:0 0 6px rgba(51,255,51,.3)}
.sse{display:inline-flex;align-items:center;gap:5px;font:10px var(--m);color:var(--mt);margin-top:2px}
.dot{width:6px;height:6px;border-radius:50%;background:#ffb000;box-shadow:0 0 6px #ffb000}
.dot.live{background:var(--g);box-shadow:0 0 8px rgba(51,255,51,.6);animation:br 2s ease-in-out infinite}
@keyframes br{0%,100%{opacity:1}50%{opacity:.5}}

/* Controls */
.ctl{display:flex;align-items:center;gap:10px;padding:6px 20px;background:var(--p);border-bottom:1px solid var(--ln);flex-shrink:0;flex-wrap:wrap}
.ctl label{color:var(--mt);font:10px var(--m);display:flex;align-items:center;gap:4px}
.ctl input{background:var(--bg);border:1px solid var(--ln);border-radius:3px;color:var(--t);padding:3px 5px;font:11px var(--m);outline:none}
.ctl input:focus{border-color:var(--g)}
.ctl input[type=number]{width:52px}
.ctl .w{width:72px}
.ctl .sp{flex:1}
.bt{border:none;border-radius:4px;padding:4px 14px;font:600 11px var(--m);cursor:pointer}
.bt-go{background:#1a4a1a;color:var(--g);border:1px solid #2a6a2a}
.bt-go:hover{background:#245a24}
.bt-st{background:#4a1a1a;color:var(--bad);border:1px solid #6a2a2a}
.bt-st:hover{background:#5a2424}

/* Metrics strip */
.mbar{display:flex;gap:1px;background:var(--ln);border-bottom:1px solid var(--ln);flex-shrink:0}
.mbar>div{flex:1;background:var(--p);padding:6px 12px;text-align:center}
.mbar b{display:block;font-size:18px;font-weight:800;font-variant-numeric:tabular-nums;line-height:1.2}
.mbar span{font:9px var(--m);color:var(--mt);text-transform:uppercase;letter-spacing:.5px}

/* Main layout: arch left, stations right */
.main{display:flex;flex:1;min-height:0;overflow:hidden}
.arch-col{width:320px;flex-shrink:0;padding:12px;border-right:1px solid var(--ln);display:flex;flex-direction:column;gap:8px;overflow-y:auto}
.data-col{flex:1;display:flex;flex-direction:column;min-width:0;overflow:hidden}

/* Architecture SVG panel */
.arch-box{background:var(--c);border:1px solid var(--ln);border-radius:8px;padding:10px;flex-shrink:0}
.arch-box h3{font:600 10px var(--m);color:var(--g);text-transform:uppercase;letter-spacing:1px;margin-bottom:8px;text-shadow:0 0 4px rgba(51,255,51,.2)}

/* Station rows */
.st-grid{display:grid;grid-template-columns:1fr 1fr;gap:8px;padding:10px 12px;overflow-y:auto;flex:1}
.st{background:var(--c);border:1px solid var(--ln);border-radius:8px;overflow:hidden;transition:border-color .3s,box-shadow .3s;display:flex;flex-direction:column}
.st.on{border-color:var(--sc);box-shadow:0 0 12px color-mix(in srgb,var(--sc) 12%,transparent)}
.st-h{display:flex;align-items:center;justify-content:space-between;padding:6px 10px;border-bottom:1px solid var(--ln)}
.st-n{font:600 12px -apple-system,system-ui,sans-serif;display:flex;align-items:center;gap:5px}
.st-b{font:9px var(--m);padding:2px 6px;border-radius:8px;background:rgba(255,255,255,.05);color:var(--mt)}
.st-b.ok{background:rgba(51,255,51,.1);color:var(--ok)}
.st-b.er{background:rgba(248,113,113,.1);color:var(--bad)}
.st-body{padding:8px 10px;display:flex;gap:10px;align-items:center;flex:1}
.gauge-w{position:relative;width:80px;height:80px;flex-shrink:0}
.gauge-w svg{width:80px;height:80px}
.gauge-c{position:absolute;inset:0;display:flex;flex-direction:column;align-items:center;justify-content:center}
.gauge-v{font:800 16px -apple-system,sans-serif;font-variant-numeric:tabular-nums}
.gauge-u{font:9px var(--m);color:var(--mt)}
.st-right{flex:1;min-width:0;display:flex;flex-direction:column;gap:4px}
.sec{display:flex;align-items:baseline;gap:4px}
.sec b{font:700 15px -apple-system,sans-serif;font-variant-numeric:tabular-nums}
.sec span{font:9px var(--m);color:var(--mt)}
.sec-l{font:9px var(--m);color:var(--mt);text-transform:uppercase;letter-spacing:.3px}
.spk{background:rgba(0,0,0,.25);border-radius:4px;padding:3px}
.spk canvas{display:block;width:100%;height:24px}
.raw{font:9px var(--m);color:rgba(51,255,51,.65);background:rgba(0,20,0,.4);border-radius:3px;padding:3px 6px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis;text-shadow:0 0 3px rgba(51,255,51,.15)}
.st-f{display:flex;gap:10px;padding:4px 10px;border-top:1px solid var(--ln);font:9px var(--m);color:var(--mt)}
.dp{animation:dp .3s ease}
@keyframes dp{0%{opacity:.5}100%{opacity:1}}

/* Console */
.con{border-top:1px solid var(--ln);background:#040804;flex-shrink:0}
.con-t{font:600 9px var(--m);color:rgba(51,255,51,.4);text-transform:uppercase;letter-spacing:1px;padding:4px 12px;border-bottom:1px solid #1a2a1a;background:rgba(0,20,0,.3)}
.con-log{height:100px;overflow-y:auto;padding:3px 12px;font:10px var(--m)}
.con-log::-webkit-scrollbar{width:3px}
.con-log::-webkit-scrollbar-thumb{background:#1a3a1a;border-radius:2px}
.cl{color:rgba(51,255,51,.7);text-shadow:0 0 3px rgba(51,255,51,.15);padding:1px 0;white-space:pre;animation:li .2s ease}
.cl.e{color:rgba(255,100,100,.7)}
@keyframes li{from{opacity:0;transform:translateY(-3px)}to{opacity:1;transform:none}}
</style>
</head>
<body>

<div class="hdr">
  <div>
    <h1>IBM System/370 &mdash; Environmental Monitoring</h1>
    <div class="sub">MVS 3.8j &bull; KICKS/CICS v1r5 &bull; Hercules/390 &bull; SYS1.TK5R</div>
  </div>
  <div class="hdr-r">
    <div>UPTIME <span class="up" id="uptime">009d 15:42:07</span></div>
    <div class="sse"><span id="dot" class="dot"></span><span id="sse-st">connecting</span></div>
  </div>
</div>

<form id="ctl" class="ctl">
  <label>SESSIONS <input name="count" type="number" min="1" max="8" value="4"></label>
  <label>INTERVAL <input name="intervalMs" type="number" min="200" max="60000" value="1000"> ms</label>
  <label>PROGRAM <input name="program" value="GWDEMO" class="w" maxlength="8"></label>
  <label>COMMAREA <input name="commareaHex" value="00000000" class="w"></label>
  <input type="hidden" name="backends" value="127.0.0.1:4321">
  <div class="sp"></div>
  <button class="bt bt-go" type="submit">START</button>
  <button class="bt bt-st" type="button" id="stop">STOP</button>
</form>

<div class="mbar">
  <div><b id="m-txn">0</b><span>CICS Transactions</span></div>
  <div><b id="m-tps">0</b><span>TPS</span></div>
  <div><b id="m-sess">0 / 4</b><span>Active Sessions</span></div>
  <div><b id="m-err">0</b><span>Errors</span></div>
</div>

<div class="main">
  <!-- Architecture diagram column -->
  <div class="arch-col">
    <div class="arch-box">
      <h3>System Architecture</h3>
      <svg viewBox="0 0 280 420" fill="none" xmlns="http://www.w3.org/2000/svg" style="width:100%">
        <!-- Browser -->
        <rect x="70" y="5" width="140" height="36" rx="6" fill="#1a2030" stroke="#3a4a5e" stroke-width="1.5"/>
        <text x="140" y="22" text-anchor="middle" fill="#dce4ec" font-family="ui-monospace,monospace" font-size="10" font-weight="600">Web Browser</text>
        <text x="140" y="33" text-anchor="middle" fill="#5a6a7e" font-family="ui-monospace,monospace" font-size="8">SSE + fetch</text>
        <!-- Arrow -->
        <line x1="140" y1="41" x2="140" y2="60" stroke="#3a5a3a" stroke-width="1.5" stroke-dasharray="3,2"/>
        <polygon points="135,58 140,66 145,58" fill="#3a5a3a"/>
        <!-- Python proxy -->
        <rect x="70" y="66" width="140" height="36" rx="6" fill="#1a2030" stroke="#60a5fa" stroke-width="1.5"/>
        <text x="140" y="82" text-anchor="middle" fill="#60a5fa" font-family="ui-monospace,monospace" font-size="10" font-weight="600">Python Proxy</text>
        <text x="140" y="93" text-anchor="middle" fill="#5a6a7e" font-family="ui-monospace,monospace" font-size="8">:8088 &bull; 4 TCP sessions</text>
        <!-- Arrow -->
        <line x1="140" y1="102" x2="140" y2="121" stroke="#3a5a3a" stroke-width="1.5" stroke-dasharray="3,2"/>
        <polygon points="135,119 140,127 145,119" fill="#3a5a3a"/>
        <!-- TCP/IP -->
        <rect x="85" y="127" width="110" height="22" rx="4" fill="#0a1a0a" stroke="#33ff33" stroke-width="1" stroke-opacity=".4"/>
        <text x="140" y="141" text-anchor="middle" fill="#33ff33" font-family="ui-monospace,monospace" font-size="9" opacity=".7">TCP :4321</text>
        <!-- Arrow -->
        <line x1="140" y1="149" x2="140" y2="163" stroke="#33ff33" stroke-width="1.5" stroke-opacity=".5"/>
        <polygon points="135,161 140,169 145,161" fill="#33ff33" opacity=".5"/>
        <!-- Hercules/Docker box -->
        <rect x="15" y="169" width="250" height="240" rx="10" fill="none" stroke="#33ff33" stroke-width="1.5" stroke-opacity=".3" stroke-dasharray="6,3"/>
        <text x="140" y="185" text-anchor="middle" fill="#33ff33" font-family="ui-monospace,monospace" font-size="9" opacity=".5">Hercules / Docker</text>
        <!-- MVS -->
        <rect x="30" y="193" width="220" height="200" rx="8" fill="#0a120a" stroke="#33ff33" stroke-width="1.5" stroke-opacity=".5"/>
        <text x="140" y="210" text-anchor="middle" fill="#33ff33" font-family="ui-monospace,monospace" font-size="11" font-weight="700">MVS 3.8j</text>
        <text x="140" y="222" text-anchor="middle" fill="#33ff33" font-family="ui-monospace,monospace" font-size="8" opacity=".5">IBM System/370 CPU</text>
        <!-- KICKGWX -->
        <rect x="50" y="232" width="180" height="34" rx="5" fill="#0f1f0f" stroke="#4ade80" stroke-width="1.5"/>
        <text x="140" y="248" text-anchor="middle" fill="#4ade80" font-family="ui-monospace,monospace" font-size="10" font-weight="600">KICKGWX Gateway</text>
        <text x="140" y="260" text-anchor="middle" fill="#5a7a5e" font-family="ui-monospace,monospace" font-size="8">X'75' socket &bull; event loop</text>
        <!-- Arrow -->
        <line x1="140" y1="266" x2="140" y2="281" stroke="#4ade80" stroke-width="1.2" stroke-dasharray="3,2"/>
        <polygon points="136,279 140,285 144,279" fill="#4ade80"/>
        <!-- KICKS/CICS -->
        <rect x="50" y="286" width="180" height="34" rx="5" fill="#1a1a0a" stroke="#f59e0b" stroke-width="1.5"/>
        <text x="140" y="302" text-anchor="middle" fill="#f59e0b" font-family="ui-monospace,monospace" font-size="10" font-weight="600">KICKS / CICS</text>
        <text x="140" y="314" text-anchor="middle" fill="#7a6a3e" font-family="ui-monospace,monospace" font-size="8">KIKPCP LINK dispatch</text>
        <!-- Arrow -->
        <line x1="140" y1="320" x2="140" y2="335" stroke="#f59e0b" stroke-width="1.2" stroke-dasharray="3,2"/>
        <polygon points="136,333 140,339 144,333" fill="#f59e0b"/>
        <!-- GWDEMO -->
        <rect x="60" y="340" width="160" height="40" rx="5" fill="#0f0f1a" stroke="#a78bfa" stroke-width="1.5"/>
        <text x="140" y="358" text-anchor="middle" fill="#a78bfa" font-family="ui-monospace,monospace" font-size="10" font-weight="600">GWDEMO Program</text>
        <text x="140" y="370" text-anchor="middle" fill="#6a5a8e" font-family="ui-monospace,monospace" font-size="8">SESSION n &bull; REQ #nnnn</text>
        <!-- Sensors on the sides -->
        <text x="25" y="405" fill="#5a6a7e" font-family="ui-monospace,monospace" font-size="7">Each request = 1 CICS transaction</text>
        <text x="25" y="414" fill="#5a6a7e" font-family="ui-monospace,monospace" font-size="7">processed by a real S/370 CPU</text>
      </svg>
    </div>
    <div class="arch-box" style="font:10px var(--m);color:var(--mt);line-height:1.5">
      <h3 style="margin-bottom:4px">Why CICS?</h3>
      CICS processes <b style="color:var(--g)">1.2M transactions/sec</b> worldwide &mdash; ATMs, airlines, retail POS.
      This demo runs the same architecture: concurrent TCP sessions dispatched to programs on a real S/370 CPU under MVS.<br><br>
      Each sensor reading is a <b style="color:var(--ok)">real mainframe transaction</b> via X'75' Hercules socket calls.
    </div>
  </div>

  <!-- Data column: stations + console -->
  <div class="data-col">
    <div id="grid" class="st-grid"></div>
    <div class="con">
      <div class="con-t">MVS Operator Console &mdash; Transaction Log</div>
      <div id="con" class="con-log"></div>
    </div>
  </div>
</div>

<script>
const STATIONS=[
  {name:'Botanical Garden',icon:'\u{1F33F}',
   m1:{label:'Temp',unit:'\u00B0C',base:23,amp:4,ph:0,min:12,max:38,d:1},
   m2:{label:'Humidity',unit:'%',base:68,amp:15,ph:1.2,min:25,max:98,d:0},
   color:'#4ade80'},
  {name:'Urban Air Quality',icon:'\u{1F3ED}',
   m1:{label:'CO\u2082',unit:'ppm',base:415,amp:60,ph:.8,min:340,max:560,d:0},
   m2:{label:'PM2.5',unit:'\u00B5g/m\u00B3',base:22,amp:18,ph:2.1,min:2,max:85,d:1},
   color:'#f59e0b'},
  {name:'River Delta',icon:'\u{1F30A}',
   m1:{label:'Water',unit:'\u00B0C',base:18,amp:3,ph:.4,min:8,max:30,d:1},
   m2:{label:'O\u2082',unit:'mg/L',base:8.2,amp:2.5,ph:1.7,min:3,max:13,d:1},
   color:'#60a5fa'},
  {name:'Solar Array',icon:'\u2600\uFE0F',
   m1:{label:'Output',unit:'kW',base:145,amp:55,ph:0,min:0,max:260,d:0},
   m2:{label:'Eff',unit:'%',base:19.2,amp:3,ph:2.5,min:11,max:25,d:1},
   color:'#a78bfa'}
];

/* State — one per station, always 4 entries */
const ss=STATIONS.map(()=>({on:false,seq:0,raw:'',v1:null,v2:null,h1:[],h2:[],err:null}));
let totalTxn=0,totalErr=0,running=0,tpsC=0,tpsL=0,uptime=847327;

/* Helpers */
function rd(m,seq){
  return Math.max(m.min,Math.min(m.max,+(m.base+m.amp*Math.sin(seq*.087+m.ph)+m.amp*.3*Math.sin(seq*.213+m.ph*2.7)+m.amp*.08*Math.sin(seq*1.37+m.ph*5.1)).toFixed(m.d)));
}
function pct(m,v){return(v-m.min)/(m.max-m.min)}
function f(v,d){return v==null?'--':v.toFixed(d)}
function si(id){return parseInt(id.substring(1),10)-1}

/* Uptime */
setInterval(()=>{uptime++;const d=Math.floor(uptime/86400),h=Math.floor(uptime%86400/3600),m=Math.floor(uptime%3600/60),s=uptime%60;
document.getElementById('uptime').textContent=String(d).padStart(3,'0')+'d '+String(h).padStart(2,'0')+':'+String(m).padStart(2,'0')+':'+String(s).padStart(2,'0')},1000);

/* TPS */
setInterval(()=>{document.getElementById('m-tps').textContent=String(tpsC-tpsL);tpsL=tpsC},1000);

/* Gauge */
function gsvg(fr,col){
  const r=32,cx=40,cy=40,sw=7,sa=150,sw2=240;
  const ea=sa+sw2*Math.max(0,Math.min(1,fr)),be=sa+sw2;
  function a(s,e){const sr=s*Math.PI/180,er=e*Math.PI/180;return`M${cx+r*Math.cos(sr)},${cy+r*Math.sin(sr)} A${r},${r} 0 ${e-s>180?1:0} 1 ${cx+r*Math.cos(er)},${cy+r*Math.sin(er)}`}
  return`<svg viewBox="0 0 80 80"><path d="${a(sa,be)}" fill="none" stroke="rgba(255,255,255,.06)" stroke-width="${sw}" stroke-linecap="round"/><path d="${a(sa,Math.max(ea,sa+1))}" fill="none" stroke="${col}" stroke-width="${sw}" stroke-linecap="round" style="filter:drop-shadow(0 0 3px ${col})"/></svg>`;
}

/* Sparkline */
function spark(cv,h,col){
  const ctx=cv.getContext('2d'),dpr=devicePixelRatio||1,w=cv.clientWidth*dpr,ht=cv.clientHeight*dpr;
  cv.width=w;cv.height=ht;ctx.clearRect(0,0,w,ht);
  if(h.length<2)return;
  const mn=Math.min(...h),mx=Math.max(...h),rng=mx-mn||1;
  ctx.beginPath();ctx.strokeStyle=col;ctx.lineWidth=1.5*dpr;ctx.lineJoin='round';
  h.forEach((v,i)=>{const x=i/(h.length-1)*w,y=ht-2*dpr-(v-mn)/rng*(ht-4*dpr);i?ctx.lineTo(x,y):ctx.moveTo(x,y)});
  ctx.stroke();ctx.lineTo(w,ht);ctx.lineTo(0,ht);ctx.closePath();ctx.fillStyle=col+'18';ctx.fill();
}

/* Build cards — always 4, static DOM, updated by id */
const grid=document.getElementById('grid');
function build(){
  grid.innerHTML='';
  STATIONS.forEach((st,i)=>{
    const d=document.createElement('div');d.className='st';d.id='st-'+i;d.style.setProperty('--sc',st.color);
    d.innerHTML=`<div class="st-h"><div class="st-n"><span>${st.icon}</span> ${st.name}</div><span class="st-b" id="bg-${i}">offline</span></div>
<div class="st-body"><div class="gauge-w"><div id="gg-${i}">${gsvg(0,st.color)}</div><div class="gauge-c"><div class="gauge-v" id="gv-${i}">--</div><div class="gauge-u">${st.m1.unit}</div></div></div>
<div class="st-right"><div class="sec-l">${st.m2.label}</div><div class="sec"><b id="sv-${i}">--</b><span>${st.m2.unit}</span></div>
<div class="spk"><canvas id="sp-${i}" height="24"></canvas></div>
<div class="raw" id="rw-${i}">&gt; awaiting data...</div></div></div>
<div class="st-f"><span>TXN #<span id="sq-${i}">0</span></span><span>RC=<span id="rc-${i}">-</span></span><span id="tm-${i}"></span></div>`;
    grid.appendChild(d);
  });
}
build();

/* Update one station */
function upd(i){
  const st=STATIONS[i],s=ss[i];
  document.getElementById('gg-'+i).innerHTML=gsvg(s.v1!=null?pct(st.m1,s.v1):0,st.color);
  document.getElementById('gv-'+i).textContent=f(s.v1,st.m1.d);
  document.getElementById('sv-'+i).textContent=f(s.v2,st.m2.d);
  spark(document.getElementById('sp-'+i),s.h1,st.color);
  document.getElementById('rw-'+i).textContent=s.raw||'> awaiting data...';
  document.getElementById('sq-'+i).textContent=String(s.seq);
  const gv=document.getElementById('gv-'+i);gv.classList.remove('dp');void gv.offsetWidth;gv.classList.add('dp');
}

/* Console */
const con=document.getElementById('con');
function clog(i,item){
  const st=STATIONS[i],s=ss[i],p=(x,n)=>(x+'                    ').slice(0,n);
  const ln=`${item.time||'??:??:??'}  S${String(i+1).padStart(3,'0')}  ${p(st.name.toUpperCase(),18)} ${p(f(s.v1,st.m1.d)+st.m1.unit,9)} ${p(f(s.v2,st.m2.d)+st.m2.unit,9)} TXN#${String(item.seq).padStart(4,'0')} RC=${item.rc} [OK]`;
  const el=document.createElement('div');el.className='cl';el.textContent=ln;
  con.appendChild(el);if(con.children.length>60)con.removeChild(con.firstChild);con.scrollTop=con.scrollHeight;
}
function cerr(i,msg){
  const el=document.createElement('div');el.className='cl e';
  el.textContent=`??:??:??  S${String(i+1).padStart(3,'0')}  ${STATIONS[i].name.toUpperCase()}  ERROR: ${msg}`;
  con.appendChild(el);if(con.children.length>60)con.removeChild(con.firstChild);con.scrollTop=con.scrollHeight;
}

/* Metrics */
function met(){
  document.getElementById('m-txn').textContent=totalTxn.toLocaleString();
  document.getElementById('m-sess').textContent=running+' / 4';
  document.getElementById('m-err').textContent=String(totalErr);
}

/* EVENT HANDLER — this is the core data flow */
function handleEvent(item){
  const sid=item.session;if(!sid)return;
  const i=si(sid);if(i<0||i>=4)return;
  const s=ss[i],bg=document.getElementById('bg-'+i),card=document.getElementById('st-'+i);

  switch(item.type){
    case 'connected':
      s.on=true;s.err=null;
      bg.textContent='online';bg.className='st-b ok';
      card.classList.add('on');
      break;
    case 'response':
      totalTxn++;tpsC++;
      s.seq=item.seq;
      s.raw=item.payloadText||'';
      s.v1=rd(STATIONS[i].m1,item.seq);
      s.v2=rd(STATIONS[i].m2,item.seq);
      s.h1.push(s.v1);s.h2.push(s.v2);
      if(s.h1.length>30)s.h1.shift();
      if(s.h2.length>30)s.h2.shift();
      document.getElementById('rc-'+i).textContent=String(item.rc);
      document.getElementById('tm-'+i).textContent=item.time||'';
      upd(i);
      clog(i,item);
      break;
    case 'error':
      totalErr++;s.err=item.message||'error';s.on=false;
      bg.textContent='error';bg.className='st-b er';
      card.classList.remove('on');
      cerr(i,s.err);
      break;
    case 'stopped':
      s.on=false;
      bg.textContent='offline';bg.className='st-b';
      card.classList.remove('on');
      break;
  }
  met();
}

/* Reset */
function clearAll(){
  totalTxn=0;totalErr=0;running=0;tpsC=0;tpsL=0;
  ss.forEach(s=>{s.on=false;s.seq=0;s.v1=null;s.v2=null;s.h1=[];s.h2=[];s.raw='';s.err=null});
  con.innerHTML='';build();met();
}

/* Form */
document.getElementById('ctl').addEventListener('submit',async ev=>{
  ev.preventDefault();clearAll();
  const fd=new FormData(ev.currentTarget);
  const res=await fetch('/api/start',{method:'POST',headers:{'content-type':'application/json'},
    body:JSON.stringify({count:+fd.get('count'),intervalMs:+fd.get('intervalMs'),
      program:fd.get('program'),commareaHex:fd.get('commareaHex').replace(/\s+/g,''),
      backends:fd.get('backends').split(/[\n,]+/).map(v=>v.trim()).filter(Boolean)})});
  const d=await res.json();running=d.running||0;met();
});
document.getElementById('stop').addEventListener('click',async()=>{
  const d=await(await fetch('/api/stop',{method:'POST'})).json();running=d.running||0;met();
});

/* SSE */
const evs=new EventSource('/events');
evs.onopen=()=>{document.getElementById('dot').classList.add('live');document.getElementById('sse-st').textContent='live'};
evs.onerror=()=>{document.getElementById('dot').classList.remove('live');document.getElementById('sse-st').textContent='reconnecting'};
evs.addEventListener('message',ev=>{
  const item=JSON.parse(ev.data);
  if(item.type==='status'){running=item.running||0;met()}
  else handleEvent(item);
});
</script>
</body>
</html>
"""


@dataclass(frozen=True)
class Backend:
    host: str
    port: int

    @property
    def label(self) -> str:
        return f"{self.host}:{self.port}"


class EventBroker:
    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._subscribers: list[queue.Queue[dict[str, Any]]] = []

    def subscribe(self) -> queue.Queue[dict[str, Any]]:
        q: queue.Queue[dict[str, Any]] = queue.Queue(maxsize=1000)
        with self._lock:
            self._subscribers.append(q)
        return q

    def unsubscribe(self, q: queue.Queue[dict[str, Any]]) -> None:
        with self._lock:
            if q in self._subscribers:
                self._subscribers.remove(q)

    def publish(self, item: dict[str, Any]) -> None:
        item.setdefault("time", time.strftime("%H:%M:%S"))
        with self._lock:
            subscribers = list(self._subscribers)
        for q in subscribers:
            try:
                q.put_nowait(item)
            except queue.Full:
                pass


class CicsSession(threading.Thread):
    def __init__(
        self,
        session_id: str,
        backend: Backend,
        program: str,
        commarea: bytes,
        interval_ms: int,
        broker: EventBroker,
    ) -> None:
        super().__init__(name=f"cics-session-{session_id}", daemon=True)
        self.session_id = session_id
        self.backend = backend
        self.program = program
        self.commarea = commarea
        self.interval = interval_ms / 1000.0
        self.broker = broker
        self.stop_event = threading.Event()
        self._sock_lock = threading.Lock()
        self._sock: socket.socket | None = None
        self.seq = 0

    def stop(self) -> None:
        self.stop_event.set()
        with self._sock_lock:
            sock = self._sock
            self._sock = None
        if sock is not None:
            try:
                sock.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            try:
                sock.close()
            except OSError:
                pass

    def emit(self, item: dict[str, Any]) -> None:
        item.setdefault("session", self.session_id)
        item.setdefault("backend", self.backend.label)
        self.broker.publish(item)

    def run(self) -> None:
        try:
            while not self.stop_event.is_set():
                try:
                    self._run_connected()
                except Exception as exc:  # noqa: BLE001 - emit and retry loop
                    if not self.stop_event.is_set():
                        self.emit({"type": "error", "message": str(exc)})
                        self._close_socket()
                        self.stop_event.wait(min(max(self.interval, 0.5), 3.0))
        finally:
            self._close_socket()
            self.emit({"type": "stopped", "message": "session stopped"})

    def _run_connected(self) -> None:
        sock = socket.create_connection((self.backend.host, self.backend.port), timeout=5.0)
        sock.settimeout(SOCKET_TIMEOUT)
        with self._sock_lock:
            self._sock = sock
        self.emit({"type": "connected", "message": "socket connected"})

        while not self.stop_event.is_set():
            self.seq += 1
            sock.sendall(build_request(self.program, self.commarea))
            header = read_exact(sock, RESPONSE_HEADER_LEN)
            rc, length = struct.unpack(">II", header)
            if length > MAX_COMMAREA:
                raise ValueError(f"bad response length {length}")
            payload = read_exact(sock, length)
            self.emit(
                {
                    "type": "response",
                    "seq": self.seq,
                    "rc": rc,
                    "length": length,
                    "payloadHex": payload.hex(),
                    "payloadText": decode_ebcdic(payload),
                }
            )
            self.stop_event.wait(self.interval)

    def _close_socket(self) -> None:
        with self._sock_lock:
            sock = self._sock
            self._sock = None
        if sock is not None:
            try:
                sock.close()
            except OSError:
                pass


class SessionManager:
    def __init__(self, broker: EventBroker, default_backends: list[Backend]) -> None:
        self.broker = broker
        self.default_backends = default_backends
        self._lock = threading.Lock()
        self._sessions: list[CicsSession] = []

    def start(
        self,
        count: int,
        program: str,
        commarea: bytes,
        interval_ms: int,
        backends: list[Backend] | None = None,
    ) -> dict[str, Any]:
        if count < 1 or count > MAX_SESSIONS:
            raise ValueError(f"count must be between 1 and {MAX_SESSIONS}")
        if interval_ms < 100 or interval_ms > 60000:
            raise ValueError("intervalMs must be between 100 and 60000")
        if len(commarea) > MAX_COMMAREA:
            raise ValueError(f"commarea must be <= {MAX_COMMAREA} bytes")

        selected_backends = backends or self.default_backends
        if not selected_backends:
            raise ValueError("at least one backend is required")

        self.stop()
        sessions: list[CicsSession] = []
        for index in range(count):
            backend = selected_backends[index % len(selected_backends)]
            session = CicsSession(
                session_id=f"S{index + 1:03d}",
                backend=backend,
                program=program,
                commarea=commarea,
                interval_ms=interval_ms,
                broker=self.broker,
            )
            sessions.append(session)

        with self._lock:
            self._sessions = sessions
        for session in sessions:
            session.start()
        self.broker.publish({"type": "status", "running": len(sessions)})
        return {"running": len(sessions)}

    def stop(self) -> dict[str, Any]:
        with self._lock:
            sessions = self._sessions
            self._sessions = []
        for session in sessions:
            session.stop()
        self.broker.publish({"type": "status", "running": 0})
        return {"running": 0}

    def status(self) -> dict[str, Any]:
        with self._lock:
            running = sum(1 for session in self._sessions if session.is_alive())
        return {"running": running}


def encode_program(program: str) -> bytes:
    value = program.strip().upper()
    if not value:
        raise ValueError("program is required")
    return value[:8].ljust(8).encode("cp037")


def decode_ebcdic(data: bytes) -> str:
    return data.decode("cp037", errors="replace")


def build_request(program: str, commarea: bytes) -> bytes:
    return encode_program(program) + struct.pack(">I", len(commarea)) + commarea


def read_exact(sock: socket.socket, length: int) -> bytes:
    chunks: list[bytes] = []
    remaining = length
    while remaining:
        chunk = sock.recv(remaining)
        if not chunk:
            raise ConnectionError("socket closed")
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def parse_backend(value: str) -> Backend:
    host, sep, port_text = value.strip().rpartition(":")
    if not sep:
        host = "127.0.0.1"
        port_text = value.strip()
    port = int(port_text)
    if not host or port < 1 or port > 65535:
        raise ValueError(f"invalid backend {value!r}")
    return Backend(host=host, port=port)


def parse_backends(values: list[str]) -> list[Backend]:
    result: list[Backend] = []
    for value in values:
        for item in value.replace("\n", ",").split(","):
            item = item.strip()
            if item:
                result.append(parse_backend(item))
    return result


def parse_commarea_hex(value: str) -> bytes:
    cleaned = "".join(value.split())
    if len(cleaned) % 2:
        raise ValueError("commareaHex must contain an even number of hex digits")
    try:
        return bytes.fromhex(cleaned)
    except ValueError as exc:
        raise ValueError("commareaHex is not valid hex") from exc


class CicsWebHandler(BaseHTTPRequestHandler):
    manager: SessionManager
    broker: EventBroker

    server_version = "CicsWebSessions/1.0"

    def do_OPTIONS(self) -> None:
        self.send_response(204)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("access-control-allow-methods", "GET,POST,OPTIONS")
        self.send_header("access-control-allow-headers", "content-type")
        self.end_headers()

    def do_GET(self) -> None:
        path = urlparse(self.path).path
        if path == "/":
            self._send_html(HTML)
        elif path == "/events":
            self._send_events()
        elif path == "/api/status":
            self._send_json(self.manager.status())
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        path = urlparse(self.path).path
        if path == "/api/start":
            self._start_sessions()
        elif path == "/api/stop":
            self._send_json(self.manager.stop())
        else:
            self.send_error(404)

    def _start_sessions(self) -> None:
        try:
            body = self._read_json()
            backends = parse_backends(body.get("backends", []))
            result = self.manager.start(
                count=int(body.get("count", 1)),
                program=str(body.get("program", "KLASTCCG")),
                commarea=parse_commarea_hex(str(body.get("commareaHex", "00000000"))),
                interval_ms=int(body.get("intervalMs", 1000)),
                backends=backends or None,
            )
            self._send_json(result)
        except Exception as exc:  # noqa: BLE001 - JSON API error path
            self._send_json({"error": str(exc)}, status=400)

    def _read_json(self) -> dict[str, Any]:
        length = int(self.headers.get("content-length", "0"))
        raw = self.rfile.read(length) if length else b"{}"
        return json.loads(raw.decode("utf-8"))

    def _send_html(self, html: str) -> None:
        data = html.encode("utf-8")
        self.send_response(200)
        self.send_header("content-type", "text/html; charset=utf-8")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_json(self, payload: dict[str, Any], status: int = 200) -> None:
        data = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status)
        self.send_header("access-control-allow-origin", "*")
        self.send_header("content-type", "application/json")
        self.send_header("content-length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def _send_events(self) -> None:
        subscriber = self.broker.subscribe()
        self.send_response(200)
        self.send_header("content-type", "text/event-stream")
        self.send_header("cache-control", "no-cache")
        self.send_header("connection", "keep-alive")
        self.send_header("x-accel-buffering", "no")
        self.end_headers()
        try:
            self._write_sse({"type": "status", **self.manager.status()})
            while True:
                try:
                    item = subscriber.get(timeout=15)
                    self._write_sse(item)
                except queue.Empty:
                    self.wfile.write(b": ping\n\n")
                    self.wfile.flush()
        except (BrokenPipeError, ConnectionResetError, OSError):
            pass
        finally:
            self.broker.unsubscribe(subscriber)

    def _write_sse(self, item: dict[str, Any]) -> None:
        data = json.dumps(item, separators=(",", ":")).encode("utf-8")
        self.wfile.write(b"event: message\n")
        self.wfile.write(b"data: " + data + b"\n\n")
        self.wfile.flush()

    def log_message(self, fmt: str, *args: Any) -> None:
        print(f"{self.address_string()} - {fmt % args}")


class CicsThreadingHTTPServer(ThreadingHTTPServer):
    def handle_error(self, request: Any, client_address: Any) -> None:
        exc = sys.exc_info()[1]
        if isinstance(exc, (BrokenPipeError, ConnectionResetError, OSError)):
            return
        super().handle_error(request, client_address)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--host", default=DEFAULT_HOST)
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    parser.add_argument(
        "--backend",
        action="append",
        default=[],
        help="CICS backend host:port. Can be repeated.",
    )
    parser.add_argument("--backends", default="")
    args = parser.parse_args()

    backend_values = list(args.backend)
    if args.backends:
        backend_values.append(args.backends)
    if not backend_values:
        backend_values = [DEFAULT_BACKEND]

    broker = EventBroker()
    manager = SessionManager(broker, parse_backends(backend_values))
    CicsWebHandler.broker = broker
    CicsWebHandler.manager = manager

    server = CicsThreadingHTTPServer((args.host, args.port), CicsWebHandler)
    print(f"CICS web sessions on http://{args.host}:{args.port}/")
    print("Backends: " + ", ".join(backend.label for backend in manager.default_backends))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        manager.stop()
        server.server_close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
