User = new Meteor.Collection('users')

now_time = -> (new Date()).getTime() # 現在時刻取得

if Meteor.isClient
  Meteor.startup ->
    unless User.find(_id: Session.get('user_id')).count() # Userが無かったら
      user_id = User.insert(last_keepalive: now_time()) # Userを新規作成
      Session.set('user_id', user_id) # user_idをSessionに記憶

  Meteor.setInterval ->
    User.update {_id: Session.get('user_id')}, {$set: {last_keepalive: (new Date()).getTime()}} # user_idの一致するUserの時間を更新する
  , 10 * 1000 # 10秒毎

  Template.users.count = ->
    User.find().count()

if Meteor.isServer
  batch_interval = 15*1000 # 15秒

  Meteor.setInterval ->
    User.remove({last_keepalive: undefined}) # 変なデータ削除
    User.remove({last_keepalive: {$lt: now_time() - batch_interval * 10}}) # 150秒以上更新の無いUserを削除
  , batch_interval
