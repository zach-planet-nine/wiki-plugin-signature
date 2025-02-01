# signature plugin, server-side component
# These handlers are launched with the wiki server. 

fs = require 'fs'
path = require 'path'
sessionless = require 'sessionless-node'

startServer = (params) -> (
  app = params.app
  argv = params.argv

  # this is meant to be .wiki/status/owners.json, but any valid path with the correct json will work
  idFile = argv.id || ''

  # saveKeys = # tbd

  # getKeys = # tbd

  # newkey = () -> Math.floor(Math.random()*1000000).toString()
  # if getKeys() # return keys we're good
  # else 
  # keys = sessionless.generateKeys saveKeys getKeys

  keys = {}

  fs.exists idFile, (exists) ->
    if exists
      fs.readFile idFile, (err, data) -> 
        if err then return cb err
        keys = JSON.parse(data)

  app.get '/plugin/signature/key', (req, res) ->
    console.log 'keys', keys
    res.json {public: keys.pubKey, algo:'ecdsa'}

  app.get '/plugin/signature/:thing', (req, res) ->
    console.log 'got a request to sign'
    sessionless.sign(req.params.thing)
      .then (signature) -> 
        console.log 'signature', signature
        res.json {signature}
      .catch (err) ->
        console.error err)

module.exports = {startServer}
