-module(chat_server).
-export([start_server/1]).

% --------------------------------Start function
start_server(Port) ->
    Pid_db =  spawn(fun() ->
        Db = ets:new(ok, [set,  named_table]),
        server_and_db(Db, [], []) end),
    register(db_name, Pid_db),
    Pid = spawn(fun() ->
            {ok, Listen} = gen_tcp:listen(Port, [binary, {active, false}]),
            spawn(fun() -> acceptor(Listen) end),
            timer:sleep(infinity)
        end),
{ok, Pid}.

% --------------------------------Utile function

is_connect_now(User_name, Socket_login) ->
    Result = lists:foldl(
        fun({_, Value}, Result) ->
            case Value == User_name of
                true -> Result + 1;
                false -> Result + 0
            end
        end, 0, Socket_login),
    Result.

send_message_to_all(Socket, Msg, Socket_login) ->
    lists:map(fun({X_socket, X_name}) ->
        case X_socket == Socket of
            true ->
                nothing;
            false ->
                io:format("socket ====== ~p and name == ~p~n", [X_socket, X_name]),
                X_name_bin = list_to_binary(X_name),
                gen_tcp:send(X_socket, list_to_binary(Msg)),
                gen_tcp:send(X_socket, <<"[User: ", X_name_bin/binary,"]-> ">>)
        end
    end,
    Socket_login).

get_user_with_name(User_name, Socket_login) ->
    User = lists:foldl(fun({Key, Value}, Result) ->
            case Value == User_name of
                true -> [{Key, Value} | Result] ;
                false -> Result
            end
        end, [], Socket_login),
    User.

% -------------------------------- Before login  function

acceptor(ListenSocket) ->
    io:format("Link~n"),
    {ok, Socket} = gen_tcp:accept(ListenSocket),
    spawn(fun() -> acceptor(ListenSocket) end),
    handle_connexion(Socket).

handle_connexion(Socket) ->
    gen_tcp:send(Socket, <<"[Disconnected] : Enter your user name-> ">>),
    inet:setopts(Socket, [{active, once}]),
    receive
        {tcp_closed, _Error} ->
            nothing;
        {tcp, _, <<"quit", _/binary>>} ->
            gen_tcp:close(Socket);
        {tcp, _, Data} ->
            List_user_name = binary_to_list(Data),
            [User_name, _] = string:tokens(List_user_name, "\r"),
            db_name ! {try_connect, self(), string:trim(User_name), Socket},
            % io:format("ici 1 self = ~p, User = ~p~n", [self(), User_name]),
            receive
                {error_connected, _} ->
                    gen_tcp:send(Socket, <<"\n___ERROR user! ", Data/binary, "is already connected\n">>),
                    handle_connexion(Socket);
                {Data_client, Socket_login} ->
                    io:format("socket login ====== ~p~n", [Socket_login]),
                    New_connection_msg = "\n|----> User " ++ User_name ++ " is connected\n",
                    send_message_to_all(Socket, New_connection_msg, Socket_login),
                    gen_tcp:send(Socket, <<"\n_____________Welcome! ", Data/binary, "\n">>),
                    client_cmd(Socket, User_name, Data_client)
            end;
        {tcp, _Socket} ->
            gen_tcp:send(Socket, <<"Error bad cmd\n">>),
            handle_connexion(Socket)
    end.

% -------------------------------- After login command function

client_cmd(Socket, User, Self_data) ->
    User_binary = list_to_binary(User),
    gen_tcp:send(Socket, <<"[User: ", User_binary/binary,"]-> ">>),
    inet:setopts(Socket, [{active, once}]),

    receive
        {tcp_closed, _Error} ->
            db_name ! {disconnect, User, Socket};

        {tcp, _Socket, <<"quit", _/binary>>} ->
            db_name ! {disconnect, User, Socket};

        {tcp, _Socket, <<"send ", Data/binary>>} ->
            List_msg = binary_to_list(Data),
            case string:tokens(List_msg, ":") of
            [Dest, Msg] ->
                Dest_clean = string:trim(Dest),
                db_name ! {send_message, Socket, Dest_clean, User, Msg};
            _ ->
                gen_tcp:send(Socket, <<"Error bad request. Exmple request -> send User_name : your message \n">>)
            end,
            client_cmd(Socket, User, Self_data);
        {tcp, _Socket, <<"send_all ", Data/binary>>} ->
            List_msg = binary_to_list(Data),
            case string:tokens(List_msg, ":") of
            [Msg] ->
                New_msg = "\n| From " ++ User ++ " ----> " ++ Msg,
                db_name ! {send_message_to_all, Socket, User, New_msg};
            _ ->
                gen_tcp:send(Socket, <<"Error bad request. Exmple request -> send_all : your message \n">>)
            end,
            client_cmd(Socket, User, Self_data);
        {tcp, _Socket} ->
            gen_tcp:send(Socket, <<"Error bad cmd\n">>),
            client_cmd(Socket, User, Self_data)
    end.


% -------------------------------- Server and Data base function

server_and_db(Db, Socket_login, Msg_history)->
    receive
        {disconnect, User_name, User_socket} ->
            Logout_msg = "\n|----> User " ++ User_name ++ " logout\n",
            send_message_to_all(User_socket, Logout_msg, Socket_login),
            New_socket_login = lists:keydelete(User_socket, 1, Socket_login),
            gen_tcp:close(User_socket),
            server_and_db(Db, New_socket_login, Msg_history);

        {try_connect, From, User_name, Socket} ->
            case ets:lookup(Db, User_name) of
                [] ->
                    self() ! {creat_user, From, User_name, Socket},
                    server_and_db(Db, Socket_login, Msg_history);
                [Client_data] ->
                    case is_connect_now(User_name, Socket_login) of
                        1 ->
                            From ! {error_connected, "Error"},
                            server_and_db(Db, Socket_login, Msg_history);
                        0 ->
                            New_socket_login = lists:append(Socket_login, [{Socket, User_name}]),
                            io:format("Socket_login = ~p.~n", [New_socket_login]),
                            gen_tcp:send(Socket, list_to_binary(Msg_history)),
                            From ! {Client_data, Socket_login},
                            server_and_db(Db, New_socket_login, Msg_history)
                    end
            end;
        {creat_user, From, User_name, Socket} ->
            ets:insert(Db, {User_name,  [{msg, []}, {pid, Socket}]}),
            [Client_data] = ets:lookup(Db, User_name),
            New_socket_login = lists:append(Socket_login, [{Socket, User_name}]),
            % io:format("Socket_login = ~p.~n", [New_socket_login]),
            From ! {Client_data, Socket_login},
            server_and_db(Db, New_socket_login, Msg_history);

        {send_message, Sender_socket, User_name,  Self_user, Msg} ->
            case get_user_with_name(User_name, Socket_login) of
                [] -> gen_tcp:send(Sender_socket, list_to_binary("\nError user not found\n")),
                    server_and_db(Db, Socket_login, Msg_history);
                [{Us_socket, _Us_name}] ->
                    New_msg_history = lists:append(Msg_history, ["--> From " ++ Self_user ++ " : " ++ Msg]),
                    New_msg = lists:append("\n|----> From " ++ Self_user ++ " :", Msg),
                    gen_tcp:send(Us_socket, list_to_binary(New_msg)),
                    User_bin = list_to_binary(User_name),
                    gen_tcp:send(Us_socket, <<"[User: ", User_bin/binary,"]-> ">>),
                    io:format("User socket = ~p~n", [Us_socket]),
                    server_and_db(Db, Socket_login, New_msg_history)
            end;
        {send_message_to_all, Socket, User, Msg} ->
            New_msg_history = lists:append(Msg_history, ["--> From " ++ User ++ "Msg : " ++ Msg ++ "\n"]),
            send_message_to_all(Socket, Msg, Socket_login),
            server_and_db(Db, Socket_login, New_msg_history)
    end.
