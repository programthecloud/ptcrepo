%%% Chat utility based on messenger.erl from Getting Started With Erlang
%%% http://www.erlang.org/doc/getting_started/conc_prog.html#id67060
%%%
%%% User interface:
%%% logon(Name)
%%%     One user at a time can log in from each Erlang node in the
%%%     system chatserver: and choose a suitable Name. If the Name
%%%     is already logged in at another node or if someone else is
%%%     already logged in at the same node, login will be rejected
%%%     with a suitable error message.
%%% logoff()
%%%     Logs off anybody at at node
%%% message(ToName, Message)
%%%     sends Message to ToName. Error messages if the user of this 
%%%     function is not logged on or if ToName is not logged on at
%%%     any node.
%%%
%%% One node in the network of Erlang nodes runs a server which maintains
%%% data about the logged on users. The server is registered as "chatserver"
%%% Each node where there is a user logged on runs a client process registered
%%% as "chat_client" 
%%%
%%% Protocol between the client processes and the server
%%% ----------------------------------------------------
%%% 
%%% To server: {ClientPid, logon, UserName}
%%% Reply {chatserver, stop, user_exists_at_other_node} stops the client
%%% Reply {chatserver, logged_on} logon was successful
%%%
%%% To server: {ClientPid, logoff}
%%% Reply: {chatserver, logged_off}
%%%
%%% To server: {ClientPid, logoff}
%%% Reply: no reply
%%%
%%% To server: {ClientPid, message_to, ToName, Message} send a message
%%% Reply: {chatserver, stop, you_are_not_logged_on} stops the client
%%% Reply: {chatserver, receiver_not_found} no user with this name logged on
%%% Reply: {chatserver, sent} Message has been sent (but no guarantee)
%%%
%%% To client: {message_from, Name, Message},
%%%
%%% Protocol between the "commands" and the client
%%% ----------------------------------------------
%%%
%%% Started: chat:client(Server_Node, Name)
%%% To client: logoff
%%% To client: {message_to, ToName, Message}
%%%
%%% Configuration: change the server_node() function to return the
%%% name of the node where the chatserver runs
-module(chat).
-export([start_server/0, server/1, logon/1, logoff/0, client/2, send/1]).
%%% Change the function below to return the name of the node where the
%%% chatserver server runs
server_node() ->
    chatserver@walker.
%%% This is the server process for the "chatserver"
%%% the user list has the format [{ClientPid1, Name1},{ClientPid22, Name2},...]
server(User_List) ->
    receive
        {From, logon, Name} ->
            New_User_List = server_logon(From, Name, User_List),
            server(New_User_List);
        {From, logoff} ->
            New_User_List = server_logoff(From, User_List),
            server(New_User_List);
        {From, broadcast, Message} ->
            [ server_transfer(From, element(2,X), Message, User_List) 
              || X <- User_List, element(1,X) /= From],
            io:format("list is now: ~p~n", [User_List]),
            server(User_List)
    end.
%%% Start the server
start_server() ->
    register(chatserver, spawn(chat, server, [[]])).
%%% Server adds a new user to the user list
server_logon(From, Name, User_List) ->
    %% check if logged on anywhere else
    case lists:keymember(Name, 2, User_List) of
        true ->
            From ! {chatserver, stop, user_exists_at_other_node},  %reject logon
            User_List;
        false ->
            From ! {chatserver, logged_on},
            [{From, Name} | User_List]        %add user to the list
    end.
%%% Server deletes a user from the user list
server_logoff(From, User_List) ->
    lists:keydelete(From, 1, User_List).
%%% Server transfers a message between user
server_transfer(From, To, Message, User_List) ->
    %% check that the user is logged on and who he is
    case lists:keysearch(From, 1, User_List) of
        false ->
            From ! {chatserver, stop, you_are_not_logged_on};
        {value, {From, Name}} ->
            server_transfer(From, Name, To, Message, User_List)
    end.
%%% If the user exists, send the message
server_transfer(From, Name, To, Message, User_List) ->
    %% Find the receiver and send the message
    case lists:keysearch(To, 2, User_List) of
        false ->
            io:format("uh oh: ~n", To),
            From ! {chatserver, receiver_not_found};
        {value, {ToPid, To}} ->
            ToPid ! {message_from, Name, Message}, 
            From ! {chatserver, sent} 
    end.
%%% User Commands
logon(Name) ->
    case whereis(chat_client) of 
        undefined ->
            register(chat_client, 
                     spawn(chat, client, [server_node(), Name]));
        _ -> already_logged_on
    end.
logoff() ->
    chat_client ! logoff.
    
send(Message) ->
    case whereis(chat_client) of % Test if the client is running
        undefined ->
            not_logged_on;
        _ -> chat_client ! {broadcast, Message},
             ok
end.
      
%%% The client process which runs on each node
client(Server_Node, Name) ->
    {chatserver, Server_Node} ! {self(), logon, Name},
    await_result(),
    client(Server_Node).
client(Server_Node) ->
    receive
        logoff ->
            {chatserver, Server_Node} ! {self(), logoff},
            exit(normal);
        {message_to, ToName, Message} ->
            {chatserver, Server_Node} ! {self(), message_to, ToName, Message},
            await_result();
        {broadcast, Message} ->
            {chatserver, Server_Node} ! {self(), broadcast, Message},
            await_result();        
        {message_from, FromName, Message} ->
            io:format("Message from ~p: ~p~n", [FromName, Message])
    end,
    client(Server_Node).
%%% wait for a response from the server
await_result() ->
    receive
        {chatserver, stop, Why} -> % Stop the client 
            io:format("~p~n", [Why]),
            exit(normal);
        {chatserver, What} ->  % Normal response
            io:format("~p~n", [What])
    end.