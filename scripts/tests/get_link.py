import urllib.request, re

url = 'https://kenney.nl/assets/pirate-kit'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    links = re.findall(r'href=[\'"]([^\'"]+pirate-kit\.zip)[\'"]', html)
    if links: 
        print('DOWNLOAD_LINK:', links[0])
    else: 
        print('No zip link found in HTML.')
except Exception as e:
    print('Error:', e)
