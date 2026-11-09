#!/usr/bin/env python3
"""Check real WDA; a tap is sent only with explicit --tap X Y (iOS points)."""
import argparse
import json
import urllib.request
import urllib.error

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--tap', nargs=2, type=int, metavar=('X', 'Y'))
args = parser.parse_args()
# Do not use system HTTP proxies for the local USB endpoint.
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
def request(method, path, body=None):
    payload = None if body is None else json.dumps(body).encode()
    req = urllib.request.Request('http://127.0.0.1:8100/' + path, data=payload, method=method, headers={'Content-Type':'application/json'})
    with opener.open(req, timeout=12) as response:
        result = json.load(response)
    if isinstance(result.get('value'), dict) and 'error' in result['value']:
        raise RuntimeError(result['value'])
    return result

session_id = None
try:
    print('Status:', json.dumps(request('GET', 'status'), ensure_ascii=False))
    session = request('POST', 'session', {'capabilities': {'alwaysMatch': {'shouldWaitForQuiescence': False}}})
    session_id = session.get('sessionId') or session.get('value', {}).get('sessionId')
    if not session_id:
        raise RuntimeError('WDA non ha restituito una sessione')
    size = request('GET', f'session/{session_id}/window/size')['value']
    print('Dimensioni in punti iOS:', size)
    if args.tap:
        x, y = args.tap
        if not (0 <= x < size['width'] and 0 <= y < size['height']):
            raise ValueError('Coordinate fuori schermo')
        request('POST', f'session/{session_id}/actions', {'actions': [{'type':'pointer', 'id':'finger', 'parameters':{'pointerType':'touch'}, 'actions':[
            {'type':'pointerMove','duration':0,'x':x,'y':y,'origin':'viewport'},
            {'type':'pointerDown','button':0}, {'type':'pointerUp','button':0}]}]})
        print(f'Tocco inviato a ({x}, {y}); verifica visivamente l’effetto sull’iPhone.')
except (OSError, ValueError, RuntimeError) as error:
    parser.exit(1, f'Verifica WDA fallita: {error}\n')
finally:
    if session_id:
        try: request('DELETE', f'session/{session_id}')
        except OSError: pass
