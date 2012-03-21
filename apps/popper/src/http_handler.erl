-module(http_handler).
-export([init/3, handle/2, terminate/2]).

init({tcp, http}, Req, Opts) ->
    {ok, Req, undefined_state}.

handle(Req, State) ->
	{[{<<"name">>,EventName}],_} = cowboy_http_req:qs_vals(Req),
	{Path,_} = cowboy_http_req:path(Req),
	{ok,Body,_} = cowboy_http_req:body(Req),
	[<<"apps">>,<<"popper">>,<<"channels">>,ChannelName,<<"events">>] = Path,
	{struct,EventData} = mochijson2:decode(Body),
  	[{_,ChanPid}] = channel_hub:chan_pid_by_name(ChannelName),
	channel:event(ChanPid, EventName, ChannelName, EventData),
	{ok, Req2} = cowboy_http_req:reply(200, [],Body, Req),
    {ok, Req2, State}.

terminate(Req, State) ->
    ok.
