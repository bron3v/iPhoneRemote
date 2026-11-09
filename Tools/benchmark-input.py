#!/usr/bin/env python3
"""Compare acknowledged tap request times on a noninteractive Settings title.
Run only while the Mac app is closed, because creating a session replaces its session.
"""
import json
import statistics
import time
from pathlib import Path
from wda_http import call, source, tap

session = call('POST','session',{'capabilities':{'alwaysMatch':{'shouldWaitForQuiescence':False}}})
sid=session.get('sessionId') or session.get('value',{}).get('sessionId')
if not sid: raise RuntimeError('No session ID')
p='session/'+sid+'/'
report={}
try:
    if call('GET','wda/locked')['value']: raise RuntimeError('iPhone locked; no benchmark gestures sent')
    call('POST',p+'wda/apps/launch',{'bundleId':'com.apple.Preferences'})
    time.sleep(0.8)
    tree=source(p)
    navigation=next(tree.iter('XCUIElementTypeNavigationBar'),None)
    if navigation is None: raise RuntimeError('Settings navigation bar not available; no benchmark gestures sent')
    title=next((e for e in navigation.iter('XCUIElementTypeStaticText') if e.get('name')==navigation.get('name')),None)
    if title is None: raise RuntimeError('Noninteractive Settings title not found; no benchmark gestures sent')
    report['target']=navigation.get('name')+' navigation title'
    report['measurement']='HTTP acknowledgement time; not input-to-video latency'
    for profile, settings in [('before',{'waitForIdleTimeout':10,'animationCoolOffTimeout':2}),('after',{'waitForIdleTimeout':0,'animationCoolOffTimeout':0})]:
        call('POST',p+'appium/settings',{'settings':settings})
        samples=[]
        for _ in range(3):
            if call('GET',p+'wda/activeAppInfo')['value']['bundleId']!='com.apple.Preferences':
                raise RuntimeError('Foreground app changed; benchmark stopped')
            start=time.perf_counter()
            if profile=='before': call('GET',p+'window/size')
            tap(p,title)
            samples.append(round((time.perf_counter()-start)*1000))
        report[profile]={'samples_ms':samples,'median_ms':statistics.median(samples)}
    report['success']=True
finally:
    try: call('POST',p+'appium/settings',{'settings':{'waitForIdleTimeout':0,'animationCoolOffTimeout':0}})
    finally: call('DELETE','session/'+sid)
    path=Path(__file__).resolve().parent.parent/'build/logs/input-benchmark.json'
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
