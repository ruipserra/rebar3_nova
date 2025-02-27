#!/usr/bin/env escript
%% -*- erlang -*-

-include_lib("kernel/include/file.hrl").

-define(TERM_RED, "\033[31m").
-define(TERM_GREEN, "\033[92m").
-define(TERM_YELLOW, "\033[33m").
-define(TERM_BLUE, "\033[96m").
-define(TERM_BOLD, "\033[1m").
-define(TERM_RESET, "\033[m").

-define(NOVA_PLUGIN, {rebar3_nova, {git, "https://github.com/novaframework/rebar3_nova.git", {branch, "master"}}}).

-define(NOVA_LOGO, ["  _   _                    __                                             _    ",
                    " | \\ | | _____   ____ _   / _|_ __ __ _ _ __ ___   _____      _____  _ __| | __",
                    " |  \\| |/ _ \\ \\ / / _` | | |_| '__/ _` | '_ ` _ \\ / _ \\ \\ /\\ / / _ \\| '__| |/ /",
                    " | |\\  | (_) \\ V / (_| | |  _| | | (_| | | | | | |  __/\\ V  V / (_) | |  |   < ",
                    " |_| \\_|\\___/ \\_/ \\__,_| |_| |_|  \\__,_|_| |_| |_|\\___| \\_/\\_/ \\___/|_|  |_|\\_\\",
                    "                       http://www.novaframework.org"]).

print(Mode, TextList) ->
    io:format("~s", [Mode]),
    print_lines(TextList),
    io:format("~s", [?TERM_RESET]).

print_lines([]) -> [];
print_lines([Hd|Tl]) ->
    io:format("~s~n", [Hd]),
    print_lines(Tl).

prompt_yesno(Message) ->
    case io:fread(standard_io, Message, "~s") of
        {ok, [Yes]} when Yes == "Y" orelse Yes == "y" ->
            yes;
        {ok, [No]} when No == "N" orelse No == "n" ->
            no;
        P ->
            io:format("GOT: ~p~n", [P]),
            prompt_yesno(Message)
    end.

check_for_rebar3() ->
    case os:cmd("command -v rebar3") of
        [] ->
            print(?TERM_YELLOW, ["Rebar3 could not be found in your $PATH. This might be cause you are", "running a local installation or forgot to install it."]),
            case prompt_yesno("Do you want to install rebar3? (Y/n)") of
                yes ->
                    os:cmd("wget https://s3.amazonaws.com/rebar3/rebar3 && chmod +x rebar3"),
                    os:cmd("./rebar3 local install"),
                    os:cmd("rm rebar3"),
                    print(?TERM_BLUE, ["Rebar3 is now installed. " ++ ?TERM_BOLD ++ "Remember to set your $PATH: export PATH=" ++ os:getenv("HOME") ++ "/.cache/rebar3/bin:$PATH"]),
                    print(?TERM_BLUE, ["Continues with the installation"]),
                    ok;
                no ->
                    print(?TERM_RED, ["Rebar3 is required by nova_plugins."]),
                    {error, not_installed}
            end;
        _ ->
            ok
    end.

inject_nova_plugin([]) -> [?NOVA_PLUGIN];
inject_nova_plugin([{rebar3_nova, _}|_] = L) ->
    L;
inject_nova_plugin([Hd|Tl]) ->
    [Hd|inject_nova_plugin(Tl)].

inject_plugin([], true) -> [];
inject_plugin([], false) -> [{plugins, [?NOVA_PLUGIN]}];
inject_plugin([{plugins, Plugins}|Tl], _) ->
    [{plugins, inject_nova_plugin(Plugins)}|inject_plugin(Tl, true)];
inject_plugin([Hd|Tl], false) ->
    [Hd|inject_plugin(Tl, false)].


write_terms_to_file(Filename, Terms) ->
    {ok, IoDevice} = file:open(Filename, [write]),
    TermsRep = lists:map(fun(Term) ->
                                 io_lib:format("~p.~n", [Term])
                         end, Terms),
    file:write(IoDevice, TermsRep).



main([]) ->
    %% Check for rebar3
    case check_for_rebar3() of
        ok ->
            %% Continue with the installation
            Filepath = os:getenv("HOME"),
            Rebar3Config = filename:join(Filepath, ".config/rebar3/rebar.config"),
            case file:consult(Rebar3Config) of
                {ok, Terms} ->
                    %% Inject the nova plugin
                    UpdatedRebar3Config = inject_plugin(Terms, false),
                    write_terms_to_file(Rebar3Config, UpdatedRebar3Config),
                    print(?TERM_GREEN, ?NOVA_LOGO),
                    print(?TERM_GREEN, [""]),
                    print(?TERM_GREEN, ["Congratulations, you have installed Nova plugin for rebar3!"]),
                    print(?TERM_GREEN, ["Try it out with typing:"]),
                    print(?TERM_BLUE, ["$ rebar3 new nova my_first_app"]);
                {error, _} ->
                    %% File did not exist :/
                    print(?TERM_RED, ["Reading rebar3 configuration failed. Check your file (and if it does not exist - create it). The file is:"]),
                    print(?TERM_YELLOW, Rebar3Config)
            end;
        _ ->
            print(?TERM_RED, ["Exiting installation"])
    end.
