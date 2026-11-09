"""Local diagnostic helper; attaches to the current WDA session without replacing it."""
import json
import time
import urllib.request
import xml.etree.ElementTree as ET

opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
def call(method, path, body=None):
    request = urllib.request.Request('http://127.0.0.1:8100/'+path,
        data=None if body is None else json.dumps(body).encode(), method=method,
        headers={'Content-Type':'application/json'})
    with opener.open(request,timeout=20) as response:
        result=json.load(response)
    if isinstance(result.get('value'),dict) and result['value'].get('error'):
        raise RuntimeError(result['value'])
    return result

def attach():
    sid=call('GET','status').get('sessionId')
    if not sid: raise RuntimeError('No existing WDA session; connect the Mac app first')
    return 'session/'+sid+'/'

def source(prefix): return ET.fromstring(call('GET',prefix+'source')['value'])
def tap(prefix, element):
    if element.get('enabled')=='false': raise RuntimeError('Target disabled')
    x=int(float(element.get('x'))+float(element.get('width'))/2)
    y=int(float(element.get('y'))+float(element.get('height'))/2)
    return call('POST',prefix+'actions',{'actions':[{'type':'pointer','id':'finger','parameters':{'pointerType':'touch'},'actions':[
        {'type':'pointerMove','duration':0,'origin':'viewport','x':x,'y':y},
        {'type':'pointerDown','button':0},{'type':'pointerUp','button':0}]}]})

def summarize(tree):
    print('Navigation:',[n.get('name') for n in tree.iter('XCUIElementTypeNavigationBar')])
    for n in tree.iter():
        if n.tag in {'XCUIElementTypeCell','XCUIElementTypeButton','XCUIElementTypeSwitch'} and n.get('visible')!='false':
            print(n.tag,n.get('name'),n.get('label'),n.get('value'),'enabled='+str(n.get('enabled')))
