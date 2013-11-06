express = require 'express'
request = require 'request'
http = require 'http'
fs = require 'fs'
path = require 'path'
_request = require 'request'
passport = require 'passport'
passport_instagram = require 'passport-instagram'

request = (opt, cb)->
  console.log "====="
  console.log "#{opt.method||'GET'} #{opt.url}"
  console.log opt
  console.log "====="
  await _request opt, defer e, res, body
  return cb e if e
  console.log "#{opt.method||'GET'} #{opt.url} #{res.statusCode}"
  console.log body
  console.log "====="
  return cb null, res, body



passport.serializeUser (user, cb)-> cb null, user
passport.deserializeUser (obj, cb)-> cb null, obj

passport.use new passport_instagram.Strategy
  clientID: '27d9e8e299bd43e7ab3b60709c415bc5'
  clientSecret: 'ddcc7fc4515342f9bd830e084b9761bb'
  callbackURL: 'http://localhost:4000/callback', (access_token, refresh_token, profile, cb)->
    await request 
      method: 'GET'
      url: "https://api.instagram.com/v1/users/#{profile.id}/media/recent?access_token=#{access_token}"
      defer e, res, body
    return cb e if e
    try 
      profile.feed = (JSON.parse body).data.map (datum)->
        caption: datum.caption?.text
        url: datum.images.standard_resolution?.url
        url_small: datum.images.thumbnail?.url
        url_medium: datum.images.low_resolution?.url
        url_large: datum.images.standard_resolution?.url
    catch e
      return cb e
    cb null, profile



app = new express()
app.locals.reducer_groupBy = (num)-> (p, c)->
  if p.length && (last = p[p.length - 1]).length < num
    last.push c
  else
    p.push [c]
  p

app.set 'view engine', 'jade'
app.set 'views', __dirname
app.use express.cookieParser()
app.use express.session
  secret: 'puffant-instaprint'
app.use express.bodyParser()
app.use passport.initialize()
app.use passport.session()
app.use app.router

app.get '/', passport.authenticate 'instagram'
app.get '/callback', passport.authenticate 'instagram', failureRedirect: '/failed'
app.get '/callback', (rq, rs, cb)->
  rs.redirect '/photos'

app.get '/photos/*', (rq, rs, cb)->
  return rs.redirect '/' unless rq.user
  cb null
app.get '/photos', (rq, rs, cb)->
  rs.render 'photos.jade', feed: rq.user.feed

app.get '/photos/print', (rq, rs, cb)->
  await request 
    method: 'POST'
    url: "https://api.sandbox.puffant.com/v1/1/decks/?secret=f42ce33671ba94ce246cf9a0924312ccb7ed794d"
    defer e, res, data
  return cb e if e
  return cb new Error data unless res.statusCode is 200
  try
    deck = JSON.parse data
  catch e
    return cb e

  for photo in rq.user.feed
    await request
      method: 'POST'
      url: "https://api.sandbox.puffant.com/v1/1/decks/#{deck.id}/cards/?secret=f42ce33671ba94ce246cf9a0924312ccb7ed794d"
      form: 
        url: photo.url
        url_small: photo.url_small
        url_medium: photo.url_medium
        url_large: photo.url_large
        caption: photo.caption
      defer e, res, body
    return cb e if e
    return cb new Error body unless res.statusCode is 200
    try
      card = JSON.parse body
    catch e
      return cb e

  rs.redirect deck.url
  


server = http.createServer app
await server.listen 4000, defer e
throw e if e
console.log "puffant-instaprint running on http://localhost:#{server.address().port}/"