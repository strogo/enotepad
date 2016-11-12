%%%-------------------------------------------------------------------
%%% @author aaronps
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 11. Oct 2016 13:10
%%%-------------------------------------------------------------------
-module(enotepad_file).
-author("aaronps").

-include_lib("wx/include/wx.hrl").

%% API
-export([
    simple_name/1,
    save_buffer/3, can_destroy_buffer/2, ask_save_buffer/2,
    load_buffer/2, show_open_dialog/2,
    ensure_file/1
]).

-spec simple_name('undefined' | string()) -> string().
simple_name(undefined) -> "Untitled";
simple_name(Name) -> filename:basename(Name).

-spec save_buffer(TextCtrl, FileName, boolean())
        -> {'ok', string()} | {'error', string()}
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        FileName :: string().
save_buffer(TextCtrl, FileName, true) -> save_buffer_as(TextCtrl, FileName);
save_buffer(TextCtrl, FileName, false) -> save_buffer(TextCtrl, FileName).

-spec can_destroy_buffer(TextCtrl, Filename)
        -> boolean()
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        Filename :: string().
can_destroy_buffer(TextCtrl, Filename) ->
    case wxStyledTextCtrl:getModify(TextCtrl) of
        true  -> enotepad_file:ask_save_buffer(TextCtrl, Filename) =/= false;
        false -> true
    end.

-spec ask_save_buffer(TextCtrl, Filename)
        -> boolean()
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        Filename :: string().
ask_save_buffer(TextCtrl, Filename) ->
    Message = "Do you want to save changes to " ++ simple_name(Filename) ++ "?",
    Style = ?wxYES_NO bor ?wxCANCEL bor ?wxCENTRE,

    case enotepad_util:simple_dialog(Message, Style) of
        ?wxID_YES    -> element(1,save_buffer(TextCtrl, Filename)) =:= ok;
        ?wxID_NO     -> true;
        ?wxID_CANCEL -> false
    end.

-spec save_buffer_as(TextCtrl, Filename)
        -> {'ok', string()} | {'error', string()}
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        Filename :: 'undefined' | string().
save_buffer_as(TextCtrl, undefined) ->
    save_buffer_as(TextCtrl, "*.txt");

save_buffer_as(TextCtrl, InitialName) ->
    Dialog = wxFileDialog:new(wx:null(), [
        {style, ?wxFD_SAVE bor ?wxFD_OVERWRITE_PROMPT},
        {wildCard, "Text Documents (*.txt)|*.txt|All Files (*.*)|*.*"},
        {defaultFile, InitialName}]),

    try
        case wxDialog:showModal(Dialog) of
            ?wxID_OK -> save_buffer(TextCtrl, wxFileDialog:getPath(Dialog));
            ?wxID_CANCEL -> {error, "cancelled"}
        end
    after
        wxFileDialog:destroy(Dialog)
    end.

-spec save_buffer(TextCtrl, Filename)
        -> {'ok', string()} | {'error', string()}
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        Filename :: 'undefined' | string().
save_buffer(TextCtrl, undefined) ->
    save_buffer_as(TextCtrl, "*.txt");

save_buffer(TextCtrl, Filename) ->
    case wxStyledTextCtrl:saveFile(TextCtrl, Filename) of
        true  -> {ok, Filename};
        false -> {error, "Can't save"}
    end.

-spec load_buffer(TextCtrl, Filename)
        -> 'ok' | 'error'
      when
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl(),
        Filename :: 'undefined' | string().

load_buffer(TextCtrl, Filename) ->
    case wxStyledTextCtrl:loadFile(TextCtrl, Filename) of
        true ->
            enotepad_util:refresh_scroll_width(TextCtrl),
            wxStyledTextCtrl:emptyUndoBuffer(TextCtrl),
            ok;

        false -> error % couldn't load, do nothing
    end.

-spec show_open_dialog(Parent, TextCtrl)
        -> 'undefined' | {'ok', string()}
      when
        Parent   :: wxWindow:wxWindow(),
        TextCtrl :: wxStyledTextCtrl:wxStyledTextCtrl().
show_open_dialog(Parent, TextCtrl) ->
    Dialog = wxFileDialog:new(Parent, [
        {style, ?wxFD_OPEN bor ?wxFD_FILE_MUST_EXIST},
        {wildCard, "Text Documents (*.txt)|*.txt|All Files (*.*)|*.*"}]),

    try
        case wxDialog:showModal(Dialog) of
            ?wxID_OK ->
                FullFilename = wxFileDialog:getPath(Dialog),
                case load_buffer(TextCtrl, FullFilename) of
                    ok -> {ok, FullFilename};
                    error -> undefined % @todo show an error dialog
                end;

            _ -> undefined
        end
    after
        wxFileDialog:destroy(Dialog)
    end.

-spec ensure_file(string()) -> {'yes', string()} | 'no' | 'cancel'.
ensure_file(FileName) ->
    case {filelib:is_file(FileName), filename:extension(FileName)} of
        {true, _}   -> {yes, FileName};
        {false, ""} -> ensure_file(FileName ++ ".txt");
        {false, _}  -> ask_create_file(FileName)
    end.

-spec ask_create_file(string()) -> {'yes', string()} | 'no' | 'cancel'.
ask_create_file(FileName) ->
    Message = "Cannot find the " ++ simple_name(FileName) ++ " file.\n"
           ++ "\n"
           ++ "Do you want to create a new file?",
    Style = ?wxYES_NO bor ?wxCANCEL bor ?wxCENTRE bor ?wxICON_EXCLAMATION,


    case enotepad_util:simple_dialog(Message, Style) of
        ?wxID_YES    -> create_empty_or_no(FileName);
        ?wxID_NO     -> no;
        ?wxID_CANCEL -> cancel
    end.

-spec create_empty_or_no(string()) -> {'ok', string()} | 'no'.
create_empty_or_no(FileName) ->
    case file:write_file(FileName, <<>>) of
        ok -> {yes, FileName};
        _  -> no
    end.