import requests

def alarm(json_body, dms_key):
    url = "https://dms.example.com/api/events/custom/{}".format(dms_key)
    headers = {"Content-Type": "application/json"}
    response = requests.post(url, data=json_body, headers=headers)
    res = response.json()
    print(res)
