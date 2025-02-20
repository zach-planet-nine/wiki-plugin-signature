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
  
  keys = {
    privateKey: argv.private_key,
    pubKey: argv.pub_key
  }
  sessionless.getKeys = () -> keys

  app.get '/plugin/signature/key', (req, res) ->
    if !keys.pubKey 
      res.sendStatus(404)
    console.log 'keys', keys
    res.json {public: keys.pubKey, algo:'ecdsa'}

  app.get '/plugin/signature/:thing', (req, res) ->
    console.log 'got a request to sign'
    if !keys.privateKey 
      res.sendStatus(404)
    sessionless.sign(req.params.thing)
      .then (signature) -> 
        console.log 'signature', signature
        res.json {signature}
      .catch (err) ->
        console.error err)

module.exports = {startServer}
