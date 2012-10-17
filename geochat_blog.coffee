User = new Meteor.Collection('users')
Message = new Meteor.Collection('messages')

now_time = -> (new Date()).getTime() # 現在時刻取得

if Meteor.isClient
  map = null
  markers = {}
  info_windows = {}

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
    Message.find({}, {sort: {created_at: -1}})

  Template.message.body = ->
    if info_windows[@user_id]
      info_windows[@user_id].setContent(@body)
      info_windows[@user_id].open(map, markers[@user_id])
    @body

  Template.message.created_at = ->
    date = new Date(@created_at)
    "#{date.getHours()}:#{date.getMinutes()}"

  Template.message.destroyed = ->
    info_windows[@data.user_id].close() if info_windows[@data.user_id]?

  Template.users.users = ->
    User.find()

  Template.user.marker = ->
    return unless map and @lng? and @lat?

    position = new google.maps.LatLng(@lat, @lng)
    if markers[@_id]
      markers[@_id].setPosition(position) if position
    else
      markers[@_id] = new google.maps.Marker(position: position, map: map)
      info_windows[@_id] = new google.maps.InfoWindow
    ''

  Template.user.destroyed = ->
    return unless markers[@data._id]?
    markers[@data._id].setMap(null)
    markers[@data._id] = null

    return unless info_windows[@data._id]?
    info_windows[@data._id].close()
    info_windows[@data._id] = null

  enter = false
  Template.controlls.events
    'click #fit-bounds': ->
      max_lat = max_lng = -Infinity
      min_lat = min_lng = Infinity
      for id, marker of markers
        marker = marker.getPosition()
        continue unless marker.lat() or marker.lng()
        max_lat = marker.lat() if marker.lat() > max_lat
        max_lng = marker.lng() if marker.lng() > max_lng
        min_lat = marker.lat() if marker.lat() < min_lat
        min_lng = marker.lng() if marker.lng() < min_lng

      latlng_bounds = new google.maps.LatLngBounds(
                        new google.maps.LatLng(min_lat, min_lng),
                        new google.maps.LatLng(max_lat, max_lng))
      map.fitBounds(latlng_bounds)


    'keypress #input-message': (e) ->
      enter = true if e.keyCode == 13

     'keyup #input-message': (e) ->
        return if e.keyCode != 13 or enter == false

        Message.insert
          body: $('#input-message').val()
          user_id: Session.get('user_id')
          created_at: now_time()
        $('#input-message').val('')
        enter = false

    'click #set-current-position': ->
      navigator.geolocation.getCurrentPosition (geo) ->
        User.update {_id: Session.get('user_id')}, {$set: {lat: geo.coords.latitude, lng: geo.coords.longitude}}
        $('#input-message').show()
        $('#rom').hide()

if Meteor.isServer
  batch_interval = 15*1000 # 15秒

  Meteor.setInterval ->
    User.remove({last_keepalive: undefined}) # 変なデータ削除
    User.remove({last_keepalive: {$lt: now_time() - batch_interval * 10}}) # 150秒以上更新の無いUserを削除
    Message.remove({created_at: {$lt: now_time() - batch_interval * 4}}) # 60秒以上経過した発言を削除
  , batch_interval
