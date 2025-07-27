/**
 * Created by chynajake on 12/24/18.
 */


var global;
var chats = {};

var current_chat;
var current_messages = []; // messages are filled backwards
var total_messages_size;
var INTERVAL = 5*1000;
var PAGE_SIZE = 10;

// CHAT LIST RELATED
function request_chats() {
    $.ajax({
        url: '/api/v1/chat/',
        dataType: 'json',
        success: function (data) {
            update_chat_list(data);
        }
    })
}

function update_chat_list(json_chats) {
    for (i = 0; i < json_chats.length; i++) {
        json_chat = json_chats[i];
        chat_update(json_chat);
    }
}

function create_chat_template(json_chat) {
    var id = json_chat["id"];
    var creator_email = json_chat["creator"]["email"];
    var creator_first_name = json_chat["creator"]["first_name"];
    var creator_last_name = json_chat["creator"]["last_name"];
    var avatar = json_chat["creator"]["avatar"];
    var string_element = '<li id="' + id + '" class="dialog_wrapper">' +
        '<div class="pull-right dialog_icon"><i class="fa fa-check-circle"></i></div>' +
        '<div class="pull-left dialog_photo">' +
            '<img src="' + avatar + '"></div>' +
        '<div class="dialog_content">' +
            '<div class="dialog_client">' + creator_first_name + ' ' + creator_last_name +'</div>' +
            '<div class="dialog_status">' + creator_email + '</div>' +
        '</div>' +
        '</li>';
    var el = $.parseHTML(string_element);
    return el[0];
    // USING JS
    // chat_ul = document.getElementById('dialog_list');
    //
    // dialog_client = create_element_with_class('div', ['dialog_client']);
    // dialog_client = create_element_with_class('div', ['dialog_status']);
    //
    // dialog_client = create_element_with_class('div', ['dialog_content']);
    // dialog_photo = create_element_with_class('div', ['pull-left', 'dialog_photo']);
    // dialog_photo = create_element_with_class('div', ['pull-right', 'dialog_icon']);
    //
    // dialog_wrapper = create_element_with_class('div', ['dialog_wrapper']);
}

function chat_update(json_chat) {
    $.ajax({
        url: '/api/v1/chat/{{id}}/messages/?page_size={{page_size}}'.replace('{{id}}', json_chat['id']).replace('{{page_size}}', PAGE_SIZE),
        dataType: 'json',
        success: function (data) {
            chat_ul = $("#dialog_list");
            total_messages_size = get_total_messages_size(data);
            chat_messages = data["results"];
            chat_id = json_chat['id'];
            json_chat['messages'] = chat_messages;
            if (!(chat_id in chats)) {
                chat_element = create_chat_template(json_chat);
                chat_photo = $(chat_element).find('div.dialog_photo')[0];
                chat_icon = $(chat_element).find('div.dialog_icon')[0];
                chat_photo.addEventListener("click", chat_click_handler);
                chat_icon.addEventListener("click", chat_solve_click_handler);
                chats[chat_id] = json_chat;
                chat_ul.prepend(chat_element);
                new_messages_count = 0;
            }
            else {
                chat_element = chat_ul.find("li#{{chat_id}}".replace("{{chat_id}}", chat_id));
                chat_object = chats[chat_id];
                local_messages = chat_object["messages"];
                new_messages_count = 0;
                for (i = 0; i < chat_messages.length; i++){
                    message = chat_messages[i];
                    if (!message_exists(message, local_messages)){
                        new_messages_count++;
                    }else {
                        break
                    }
                }
                chat_object["messages"] = chat_messages;
            }
            if (new_messages_count > 0){
                chat_element.detach();
                chat_ul.prepend(chat_element);
            }
        }
    });
}

function chat_click_handler() {
    li_element = this.parentNode;
    chosen_chat = chats[li_element.id];
    if (current_chat) {
        if (current_chat['id'] != chosen_chat['id']) {
            current_chat = chats[li_element.id];
            current_messages = [];
            request_chat_messages(li_element.id);
        }
    } else {
        current_chat = chats[li_element.id];
        current_messages = [];
        request_chat_messages(li_element.id);
    }

}


// SINGLE CHAT RELATED
function request_chat_messages(chat_id) {
    $.ajax({
        url: '/api/v1/chat/{{id}}/messages/?page_size={{page_size}}'.replace('{{id}}', chat_id).replace('{{page_size}}', PAGE_SIZE),
        dataType: 'json',
        success: function (data) {
            console.log(data);
            fill_chat_window(chat_id, data);
            total_messages_size = get_total_messages_size(data);
        }
    });
}

function get_total_messages_size(json_messages){
    return json_messages['count'];
}

function fill_chat_window(chat_id, json_messages){
    chat = chats[chat_id];
    messages = json_messages['results'];

    var chat_window_element = $('div.history_list');
    chat_window_element.empty();
    for (i = 0; i < messages.length; i++) {
        message = messages[i];
        current_messages.push(message);
        message_element = create_message_template(message, chat);
        chat_window_element.append(message_element);
    }
}

function chat_solve_click_handler() {
    li_element = this.parentNode;
    solve_chat(li_element.id);
}

function solve_chat(chat_id) {
    $.ajax({
        headers: {"X-CSRFToken": getCookie("csrftoken")},
        url: '/api/v1/chat/{{id}}/chat/solve/'.replace('{{id}}', chat_id),
        type: "POST",
        dataType: 'json',
        success: function(data) {
            chat_ul = $("#dialog_list");
            chat_element = chat_ul.find("li#{{chat_id}}".replace("{{chat_id}}", chat_id));
            chat_element.remove();
            delete chats[chat_id];
            if (current_chat) {
                if (current_chat['id'] == chat_id) {
                    current_chat = null;
                    current_messages = [];
                    chat_window_element = $('div.history_list');
                    chat_window_element.empty();
                }
            }
        }
    })
}


function message_exists(message, check_messages) {
    var found = false;
    for (j = 0; j < check_messages.length; j++){
        local_message = check_messages[j];
        if (local_message['id'] == message['id']){
            found = true;
            break;
        }
    }
    return found;
}

function append_message(message){
    var chat_window_element = $('div.history_list');
    current_messages.push(message);
    message_element = create_message_template(message, current_chat);
    chat_window_element.append(message_element);
}
function prepend_message(message){
    var chat_window_element = $('div.history_list');
    current_messages.unshift(message);
    message_element = create_message_template(message, current_chat);
    chat_window_element.prepend(message_element);
    // TODO scroll to bottom of window
}


function create_message_template(json_message, chat) {
    var template =
        '<div id="{{id}}" class="{{class}}">' +
            '<div class="log_photo">' +
                '<img src="{{avatar}}">' +
            '</div>' +
            '<div class="log_content">' +
                '<div class="log_text">{{text}}</div>' +
                '<div class="clearfix"></div>' +
                '<div class="log_date pull-right">{{author}}: {{date}}</div>' +
            '</div>' +
        '</div>' +
        '<div class="clearfix"></div>';
    author = json_message["author"];
    is_agent = json_message["agent_message"];
    client_avatar = chat["creator"]["avatar"];
    agent_avatar = json_message["agent_avatar"];
    create_date = json_message["create_date"];
    date = create_date.slice(0, 10);
    time = create_date.slice(11, 19);
    datetime = date + ' ' + time;
    if (is_agent) {
        avatar = json_message["agent_avatar"];
        div_classes = "history_wrapper";
    } else {
        avatar = chat["creator"]["avatar"];
        div_classes = "history_wrapper client";
    }
    message_string = template.replace("{{id}}", json_message["id"]);
    message_string = message_string.replace("{{text}}", json_message["text"]);
    message_string = message_string.replace("{{class}}", div_classes);
    message_string = message_string.replace("{{avatar}}", avatar);
    message_string = message_string.replace("{{author}}", author);
    message_string = message_string.replace("{{date}}", datetime);
    return $.parseHTML(message_string);
}

function send_message() {
    var text_box = $('div.message_panel div.message_textarea');
    var text = text_box.text();
    if (current_chat && text) {
        text_box.empty();
        send_api_message(text);
    }
}

function send_api_message(text) {
    $.ajax({
        headers: {"X-CSRFToken": getCookie("csrftoken")},
        url: '/api/v1/chat/{{id}}/messages/send/'.replace('{{id}}', current_chat['id']),
        type: "POST",
        dataType: 'json',
        data: {text: text},
        success: function (data) {
            prepend_message(data);
            chat_ul = $("#dialog_list");
            chat_element = chat_ul.find("li#{{chat_id}}".replace("{{chat_id}}", current_chat['id']));
            chat_element.detach();
            chat_ul.prepend(chat_element);
        }
    });
}

function update_messages() {
    if (current_chat) {
        $.ajax({
            url: '/api/v1/chat/{{id}}/messages/?page=1&page_size={{page_size}}'.replace('{{id}}', current_chat['id']).replace('{{page_size}}', PAGE_SIZE),
            dataType: 'json',
            success: function (data) {
                server_total_messages_size = get_total_messages_size(data);
                if (total_messages_size != server_total_messages_size){
                    total_messages_size = server_total_messages_size;
                    messages = data['results'];
                    new_messages = [];
                    for (i = 0; i < messages.length; i++){
                        message = messages[i];
                        if (!message_exists(message, current_messages)){
                            new_messages.unshift(message);
                        }
                    }
                    for (k = 0; k < new_messages.length; k++){
                        message = new_messages[k];
                        prepend_message(message);
                    }
                }
            }
        });
    }
}

function load_messages() {
    if (current_chat) {
        if ($(this).scrollTop() == 0){
            current_message_size = current_messages.length;
            if (current_message_size < total_messages_size){
                target_page = Math.floor(current_message_size / PAGE_SIZE + 1);
                $.ajax({
                    url: '/api/v1/chat/{{id}}/messages/?page={{page}}&page_size={{page_size}}'.replace('{{id}}', current_chat['id']).replace('{{page_size}}', PAGE_SIZE).replace('{{page}}', target_page),
                    dataType: 'json',
                    success: function (data) {
                        chat = current_chat['id'];
                        messages = data['results'];
                        for (i = 0; i < messages.length; i++) {
                            server_message = messages[i];
                            if (!message_exists(server_message, current_messages)) {
                                append_message(server_message);
                            }
                        }
                    }
                });
            }
        }
    }
}


$('div.history_list').on('scroll', load_messages);
request_chats();
setInterval(request_chats, INTERVAL);
setInterval(update_messages, INTERVAL);


function send_by_enter(){
    var input = document.getElementById("message_input_box");
    // Execute a function when the user releases a key on the keyboard
    input.addEventListener("keyup", function(event) {
      if (current_chat) {
          // Cancel the default action, if needed
          event.preventDefault();
          // Number 13 is the "Enter" key on the keyboard
          if (event.keyCode === 13) {
            // Trigger the button element with a click
            document.getElementById("send_message_button").click();
          }
      }
    });
}

function getCookie(name) {
  var value = "; " + document.cookie;
  var parts = value.split("; " + name + "=");
  if (parts.length == 2) return parts.pop().split(";").shift();
}

// helping functions
send_by_enter();