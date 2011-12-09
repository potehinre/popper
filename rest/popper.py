import httplib, time, hashlib, hmac, base64

try:
    import json
except ImportError:
    import simplejson as json

host    = 'localhost'
port    = 1234
app_id  = 'popper'

class Pusher(object):
    def __init__(self, app_id=None, host=None, port=None):
        _globals = globals()
        self.app_id = app_id or _globals['app_id']
        self.host = host or _globals['host']
        self.port = port or _globals['port']
        self._channels = {}

    def __getitem__(self, key):
        if not self._channels.has_key(key):
            return self._make_channel(key)
        return self._channels[key]

    def _make_channel(self, name):
        self._channels[name] = channel_type(name, self)
        return self._channels[name]

class Channel(object):
    def __init__(self, name, pusher):
        self.pusher = pusher
        self.name = name
        self.path = '/apps/%s/channels/%s/events' % (self.pusher.app_id, self.name)

    def trigger(self, event, data={}, socket_id=None):
        json_data = json.dumps(data)
        status = self.send_request(self.signed_query(event, json_data, socket_id), json_data)
        if status == 202:
            return True
        elif status == 401:
            raise AuthenticationError
        elif status == 404:
            raise NotFoundError
        else:
            raise Exception("Unexpected return status %s" % status)

    def signed_query(self, event, json_data, socket_id):
         return self.compose_querystring(event, json_data, socket_id)

    def compose_querystring(self, event, json_data, socket_id):
        ret = "name=%s" % (event)
        if socket_id:
            ret += "&socket_id=" + unicode(socket_id)
        return ret

    def send_request(self, query_string, data_string):
        signed_path = '%s?%s' % (self.path, query_string)
        http = httplib.HTTPConnection(self.pusher.host, self.pusher.port)
        http.request('POST', signed_path, data_string)
        return http.getresponse().status

    def authenticate(self, socket_id, custom_data=None):
        if custom_data:
            custom_data = json.dumps(custom_data)

        auth = self.authentication_string(socket_id, custom_data)
        r = {'auth': auth}

        if custom_data:
            r['channel_data'] = custom_data

        return r

    def authentication_string(self, socket_id, custom_string=None):
      if not socket_id:
          raise Exception("Invalid socket_id")

      string_to_sign = "%s:%s" % (socket_id, self.name)

      if custom_string:
        string_to_sign += ":%s" % custom_string

      signature = hmac.new(self.pusher.secret, string_to_sign, hashlib.sha256).hexdigest()

      return "%s:%s" % (self.pusher.key,signature)

class GoogleAppEngineChannel(Channel):
    def send_request(self, query_string, data_string):
        from google.appengine.api import urlfetch
        absolute_url = 'http://%s/%s?%s' % (self.pusher.host, self.path, query_string)
        response = urlfetch.fetch(
            url=absolute_url,
            payload=data_string,
            method=urlfetch.POST,
            headers={'Content-Type': 'application/json'}
        )
        return response.status_code

class AuthenticationError(Exception):
    pass

class NotFoundError(Exception):
    pass

channel_type = Channel

