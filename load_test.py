from websocket import create_connection
from collections import OrderedDict
import json,ujson
import time

class ConnectionNotEstablishedError(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)


class PusherClient(object):
    def __init__(self,host,port,path):
        self.connection=create_connection("ws://"+host+":"+str(port)+path)
        response = self.connection.recv()
        if not self.is_connection_established(response):
            raise ConnectionNotEstablishedError(response)
            
    def subscribe(self,channel_name,user_id):
        chan_data=OrderedDict()
        chan_data['user_id']=str(user_id)
        chan_data['user_info']=OrderedDict([("name","loadtester")])
        
        data=OrderedDict()
        data['channel']=channel_name
        data['auth']="app:lalala"
        data['channel_data'] = chan_data
        
        result=OrderedDict()
        result['event']="pusher:subscribe"
        result['data']=data
        
        subscribe_json = json.dumps(result)
        self.connection.send(subscribe_json)
        
    def unsubscribe(self,channel_name):
        result=OrderedDict()
        result['event']='pusher:unsubscribe'
        result['data']=OrderedDict([("channel",channel_name)])
        unsubscribe_json = json.dumps(result)
        self.connection.send(unsubscribe_json)
        
    def send_msg(self,channel_name,msg):
        result=OrderedDict()
        result['event']="chat_msg"
        result['data']=OrderedDict([("message",msg)])
        result['channel']=channel_name
        msg_json = json.dumps(result)
        self.connection.send(msg_json)
        
    def is_connection_established(self,response):
        result = json.loads(response)
        return result.has_key("event") and result["event"] == "pusher:connection_established"
            
if __name__ == '__main__':
    client = PusherClient("localhost",1234,"/app/popper/")
    client.subscribe("presence-chat","motherfucker")
    while True:
        client.send_msg("presence-chat","omnomnom")
        time.sleep(1)
    