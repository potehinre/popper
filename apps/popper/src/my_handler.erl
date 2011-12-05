-module(my_handler).
-behaviour(cowboy_http_handler).
-behaviour(cowboy_http_websocket_handler).
-export([init/3, handle/2, terminate/2]).
-export([websocket_init/3, websocket_handle/3,
    websocket_info/3, websocket_terminate/3]).

init({tcp, http}, Req, Options) ->
    {upgrade, protocol, cowboy_http_websocket}.

handle(Req, State) ->
    {ok, Req2} = cowboy_http_req:reply(200, [],<<"Hello World">>, Req),
    {ok, Req2, State}.

terminate(Req, State) ->
    ok.

to_pusher_format(EventName,Data) ->
    mochijson2:encode({struct,[{<< "event" >>, EventName}, {<< "data" >>, {struct,Data}}]}).

websocket_init(TransportName, Req, _Opts) ->
    erlang:start_timer(100, self(), <<"Hello">>),
    {ok, Req, undefined_state}.

websocket_handle({text,Msg}, Req,State) ->
    Decoded = mochijson2:decode(Msg),
    {struct,[{<< "event" >>, Event},{<< "data" >>,{struct,Data}}]} = mochijson2:decode(Msg),
    case Event of
	<<"pusher:subscribe">> ->
	    RespData = [{<< "presence" >>,{struct,[{<<"hash">>,<<"users">>},{<<"count">>,3}]}}],
	    Response = to_pusher_format(<< "pusher_internal:subscription_succeded" >>, RespData),
	    {reply, {text, Response}, Req, State}
    end;

websocket_handle(_Data, Req, State) ->
    {ok, Req, State}.

websocket_info({timeout, _Ref, _Msg}, Req, State) ->
    Json = mochijson2:encode({struct,[{<< "event" >>, << "pusher:connection_established" >>},
			              {<< "data" >>, {struct,[{<< "socket_id" >>, 13}]}}]}),
    {reply, {text, Json}, Req, State};

websocket_info(_Info,Req, State) ->
    {ok, Req, State}.

websocket_terminate(_Reason, _Req, _State) ->
    ok.
