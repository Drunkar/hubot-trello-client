# Dependencies:
#   "node-trello": "latest"
#
# Configuration:
#   HUBOT_TRELLO_KEY - Trello application key
#   HUBOT_TRELLO_TOKEN - Trello API token
#
# Commands:
#   hubot trello|tr update - Fetch board information
#   hubot trello|tr show - Show all lists and cards
#   hubot trello|tr lists - Show all lists
#   hubot trello|tr cards <list_name> - Show all cards in list: <list_name>
#   hubot trello|tr cards <list_name> - Show all cards in list: <list_name>
#   hubot trello|tr cards <list_name> - Show all cards in list: <list_name>
#   hubot trello|tr add card <card_name> to <list_name> - Add a new card to list: <list_name>
#   hubot c:<card_id> <comment> - Post comment to card <card_name>
#

# 特定のroomと特定のユーザーだけに反応する
# カードにコメントを記録するとき使用
valid_rooms = ["<ROOM_NAME>@conference.<TEAM_NAME>.xmpp.slack.com"]
valid_users = ["<ALLOWED_USER>", "<ALLOWED_USER>"]

board = {}
lists = {}

Trello = require 'node-trello'
trello = new Trello process.env.HUBOT_TRELLO_KEY, process.env.HUBOT_TRELLO_TOKEN

# verify that all the environment vars are available
ensureConfig = (out) ->
    out "Error: Trello app key is not specified" if not process.env.HUBOT_TRELLO_KEY
    out "Error: Trello token is not specified" if not process.env.HUBOT_TRELLO_TOKEN
    out "Error: Trello board ID is not specified" if not process.env.HUBOT_TRELLO_BOARD
    return false unless (process.env.HUBOT_TRELLO_KEY and process.env.HUBOT_TRELLO_TOKEN and process.env.HUBOT_TRELLO_BOARD)
    true


##############################
# utilities
##############################

createList = (msg, list_name) ->
    msg.send "リスト作るよー！"
    ensureConfig msg.send
    id = board["id"]
    trello.post "/1/lists", {name: list_name, idBoard: id}, (err, data) ->
        msg.send "エラーっぽい…" if err
        msg.send "作ったよー！: #{data.url}" unless err

showLists = (msg) ->
  msg.send "ボード "+ board["name"] + "のリストを探し中…"
    ensureConfig msg.send
    id = board["id"]
    msg.send "ボード " + board["name"] + " は存在しない気がします" unless id
    if id
        trello.get "/1/boards/#{id}", {lists: "open"}, (err, data) ->
            msg.send "エラーっぽい…" if err
            msg.send "#{data.name} にある全リストだよっ:" unless err and data.lists.length == 0
            msg.send "--------------------------------------------------------------" unless err and data.lists.length == 0
            msg.send "* #{list.name}" for list in data.lists unless err and data.lists.length == 0
            msg.send "--------------------------------------------------------------" unless err and data.lists.length == 0
            msg.send "ボード #{data.name} にリストはないみたい。" if data.lists.length == 0 and !err

createCard = (msg, cardName, list_name) ->
    msg.send "カードを作るよ！"
    ensureConfig msg.send
    id = lists[list_name.toLowerCase()]
    msg.send "#{list_name} っていうリストは無いと思う" unless id
    if id
        id = id.id
        trello.post "/1/cards", {name: cardName, idList: id}, (err, data) ->
            msg.send "エラーっぽい…" if err
            msg.send "できたよっ！: #{data.url}" unless err

showCards = (msg, list_name) ->
    msg.send "リスト #{list_name} のカードを探し中…"
    ensureConfig msg.send
    id = lists[list_name.toLowerCase()]
    msg.send "#{list_name} っていうリストは無かったよ！" unless id
    if id
        id = id.id
        trello.get "/1/lists/#{id}", {cards: "open"}, (err, data) ->
            msg.send "エラーっぽい…" if err
            msg.send "#{data.name} にある全カードだよっ:" unless err and data.cards.length == 0
            msg.send "--------------------------------------------------------------" unless err and data.cards.length == 0
            msg.send "* #{card.name}, id:#{card.id}, #{card.shortUrl}" for card in data.cards unless err and data.cards.length == 0
            msg.send "--------------------------------------------------------------" unless err and data.cards.length == 0
            msg.send "リスト #{data.name} にカードはないみたいね。" if data.cards.length == 0 and !err

showCardsForTree = (msg, iter_lists, list_index) ->
    ensureConfig msg.send
    msg.send "#{iter_lists[list_index].name}"
    id = lists[iter_lists[list_index].name.toLowerCase()]
    if id
        id = id.id
        trello.get "/1/lists/#{id}", {cards: "open"}, (err, data) ->
            msg.send "|        |- #{card.name}, id:#{card.id}, #{card.shortUrl}" for card in data.cards unless err and data.cards.length == 0
            if list_index < iter_lists.length-1
                showCardsForTree msg, iter_lists, list_index+1
            else
                msg.send "--------------------------------------------------------------"

showTree = (msg) ->
    msg.send "ボード "+ board["name"] + "のリストを探し中…"
    ensureConfig msg.send
    id = board["id"]
    msg.send board["name"] + "っていうボードは見つかりませんでした…" unless id
    if id
        trello.get "/1/boards/#{id}", {lists: "open"}, (err, data) ->
            msg.send "エラーっぽい…" if err
            unless err
                msg.send "ボード #{data.name} のリストとカードだよっ:" unless data.lists.length == 0
                msg.send "--------------------------------------------------------------" unless data.lists.length == 0
                i = 0
                showCardsForTree msg, data.lists, 0
            msg.send "ボード #{data.name} にまだリストは無いよ！" if data.lists.length == 0 and !err

moveCard = (msg, card_id, list_name) ->
    ensureConfig msg.send
    id = lists[list_name.toLowerCase()]
    msg.send "リスト #{list_name} は無かったです…" unless id
    if id
        id = id.id
        trello.put "/1/cards/#{card_id}/idList", {value: id}, (err, data) ->
            msg.send "エラーっぽい…" if err
            msg.send "カードをリスト #{list_name} に移動したよ！" unless err

postComment = (msg, comment, card_id) ->
    ensureConfig msg.send
    comment = msg.envelope.user.name + ": " + comment
    trello.post "/1/cards/" + card_id + "/actions/comments", {text: comment}, (err, data) ->
        msg.send "カード " + card_id + " にコメント書けなかった…" if err

fetchBoard = (msg) ->
    id = board["id"]
    trello.get "/1/boards/#{id}", (err, data) ->
        board = data
        trello.get "/1/boards/#{id}/lists", (err, data) ->
        unless err
            for list in data
                lists[list.name.toLowerCase()] = list
            msg.send "ボードの情報を更新！"

room_and_user_is_valid = (msg) ->
    if msg.envelope.user.name in valid_users and msg.envelope.room in valid_rooms
        return true
    else
        return false


##############################
# Main
##############################
module.exports = (robot) ->
    # fetch our board data when the script is loaded
    ensureConfig console.log
    trello.get "/1/boards/#{process.env.HUBOT_TRELLO_BOARD}", (err, data) ->
        board = data
        trello.get "/1/boards/#{process.env.HUBOT_TRELLO_BOARD}/lists", (err, data) ->
            for list in data
                lists[list.name.toLowerCase()] = list

    robot.respond /trello|tr update/, (msg) ->
        fetchBoard msg

    robot.respond /trello|tr show/, (msg) ->
        showTree msg

    robot.respond /trello|tr add card (.+) to (.*)/i, (msg) ->
        ensureConfig msg.send
        card_name = msg.match[2]
        list_name = msg.match[1]

        if card_name.length == 0
            msg.send "カード名を入力して！"
            return

        if list_name.length == 0
            msg.send "リスト名が無いよ！"
            return
        return unless ensureConfig()

        createCard msg, list_name, card_name

    robot.respond /trello|tr lists/, (msg) ->
        showLists msg

    robot.respond /trello|tr cards (.+)/i, (msg) ->
        showCards msg, msg.match[1]

    robot.respond /trello|tr move (\w+) (.+)/i, (msg) ->
        moveCard msg, msg.match[1], msg.match[2]

    robot.hear /c:(.+) (.+)/i, (msg) ->
        if room_and_user_is_valid msg
            postComment msg, msg.match[2], msg.match[1]

    robot.respond /trello|tr help/i, (msg) ->
        msg.send "hubot trello|tr update - Fetch board information"
        msg.send "hubot trello|tr show - Show all lists and cards"
        msg.send "hubot trello|tr lists - Show all lists"
        msg.send "hubot trello|tr cards <list_name> - Show all cards in list: <list_name>"
        msg.send "hubot trello|tr cards <list_name> - Show all cards in list: <list_name>"
        msg.send "hubot trello|tr cards <list_name> - Show all cards in list: <list_name>"
        msg.send "hubot trello|tr add card <card_name> to <list_name> - Add a new card to"
        msg.send "hubot c:<card_id> <comment> - Post comment to card <card_name>"

