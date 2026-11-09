#!/usr/bin/env python3
"""Verify one coordinate tap on a safe Settings navigation target, then return Home.
Requires a trusted, running WDA on the USB tunnel. Changes no iOS settings.
"""
import json
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
def call(method, path, body=None):
    request = urllib.request.Request('http://127.0.0.1:8100/' + path,
        data=None if body is None else json.dumps(body).encode(), method=method,
        headers={'Content-Type':'application/json'})
    with opener.open(request, timeout=30) as response:
        result = json.load(response)
    if isinstance(result.get('value'), dict) and result['value'].get('error'):
        raise RuntimeError(result['value'])
    return result

report = {}
session_id = None
try:
    session = call('POST', 'session', {'capabilities':{'alwaysMatch':{'shouldWaitForQuiescence':False}}})
    session_id = session.get('sessionId') or session.get('value', {}).get('sessionId')
    if not session_id:
        raise RuntimeError('No WDA session ID')
    prefix = f'session/{session_id}/'
    report['window_points'] = call('GET', prefix+'window/size')['value']
    call('POST', prefix+'wda/apps/launch', {'bundleId':'com.apple.Preferences'})
    before = ET.fromstring(call('GET', prefix+'source')['value'])
    targets = []
    safe_back = {'Generali','Impostazioni','Indietro','General','Settings','Back'}
    for navigation in before.iter('XCUIElementTypeNavigationBar'):
        for element in navigation.iter('XCUIElementTypeButton'):
            if (element.get('label') or element.get('name')) in safe_back:
                targets.append(element)
    for element in before.iter('XCUIElementTypeCell'):
        if any((child.get('label') or child.get('name')) in {'Generali','General'} for child in element.iter()):
            targets.append(element)
    targets = [e for e in targets if e.get('visible') != 'false' and float(e.get('width','0')) > 0 and float(e.get('height','0')) > 0]
    if not targets:
        raise RuntimeError('No safe Settings navigation target found; no tap sent')
    target = targets[0]
    x = int(float(target.get('x')) + float(target.get('width'))/2)
    y = int(float(target.get('y')) + float(target.get('height'))/2)
    size = report['window_points']
    if not (0 <= x < size['width'] and 0 <= y < size['height']):
        raise RuntimeError('Navigation target outside WDA window; no tap sent')
    report['tap'] = {'label':target.get('label') or target.get('name'), 'x':x, 'y':y}
    report['before_navigation'] = [e.get('name') for e in before.iter('XCUIElementTypeNavigationBar')]
    call('POST', prefix+'actions', {'actions':[{'type':'pointer','id':'finger','parameters':{'pointerType':'touch'},'actions':[
        {'type':'pointerMove','duration':0,'x':x,'y':y,'origin':'viewport'},
        {'type':'pointerDown','button':0},{'type':'pointerUp','button':0}]}]})
    after = ET.fromstring(call('GET', prefix+'source')['value'])
    report['after_navigation'] = [e.get('name') for e in after.iter('XCUIElementTypeNavigationBar')]
    report['navigation_changed'] = report['before_navigation'] != report['after_navigation']
    if not report['navigation_changed']:
        raise RuntimeError('Tap acknowledged but navigation change not confirmed')
    call('POST', 'wda/homescreen', {})
    report['returned_home'] = True
    report['success'] = True
finally:
    if session_id:
        try: call('DELETE', f'session/{session_id}')
        except OSError: pass
    path = Path(__file__).resolve().parent.parent/'build/logs/first-tap.json'
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print(json.dumps(report,ensure_ascii=False,indent=2))
