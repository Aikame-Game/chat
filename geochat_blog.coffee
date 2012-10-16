User = new Meteor.Collection('users')
Message = new Meteor.Collection('messages')

now_time = -> (new Date()).getTime() # 現在時刻取得

if Meteor.isClient
  map = null
  markers = {}
  Meteor.startup ->
    map_canvas = $('<div>').attr('id', 'map_canvas').appendTo('body')
    map = new google.maps.Map map_canvas[0],
      zoom: 6
      center: new google.maps.LatLng(36.031332,137.805908)
      mapTypeId: google.maps.MapTypeId.ROADMAP

    unless User.find(_id: Session.get('user_id')).count() # Userが無かったら
      user_id = User.insert(last_keepalive: now_time()) # Userを新規作成
      Session.set('user_id', user_id) # user_idをSessionに記憶

  Meteor.setInterval ->
    User.update {_id: Session.get('user_id')}, {$set: {last_keepalive: (new Date()).getTime()}} # user_idの一致するUserの時間を更新する
  , 10 * 1000 # 10秒毎

  Template.users.count = ->
    User.find().count()

  Template.messages.messages = ->
    Message.find()

  Template.message.body = ->
    @body

  Template.users.users = ->
    User.find()

  Template.user.marker = ->
    return unless map and @lng? and @lat?

    position = new google.maps.LatLng(@lat, @lng)
    if markers[@_id]
      markers[@_id].setPosition(position) if position
    else
      markers[@_id] = new google.maps.Marker(position: position, map: map)
    ''

  Template.user.destroyed = ->
    return unless markers[@data._id]?
    markers[@data._id].setMap(null)
    markers[@data._id] = null

  Template.controlls.events
    'click #submit-message': (e) ->
      Message.insert
        body: $('#input-message').val()
        user_id: Session.get('user_id')
        created_at: now_time()
      $('#input-message').val('')

    'click #set-current-position': ->
      navigator.geolocation.getCurrentPosition (geo) ->
        User.update {_id: Session.get('user_id')}, {$set: {lat: geo.coords.latitude, lng: geo.coords.longitude}}

if Meteor.isServer
  batch_interval = 15*1000 # 15秒

  Meteor.setInterval ->
    User.remove({last_keepalive: undefined}) # 変なデータ削除
    User.remove({last_keepalive: {$lt: now_time() - batch_interval * 10}}) # 150秒以上更新の無いUserを削除
    Message.remove({created_at: {$lt: now_time() - batch_interval * 4}}) # 60秒以上経過した発言を削除
  , batch_interval
