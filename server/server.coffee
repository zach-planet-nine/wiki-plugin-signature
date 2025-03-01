# signature plugin, server-side component
# These handlers are launched with the wiki server. 

fs = require 'fs'
path = require 'path'
sessionless = require 'sessionless-node'
# bdo = require 'bdo-js' // allyabase client libs need to be adapted for commonjs, and I want
#                          // to think about the best way of doing that

startServer = (params) -> (
  app = params.app
  argv = params.argv

  # this is meant to be .wiki/status/owners.json, but any valid path with the correct json will work
  idFile = argv.id || ''
  
  sessionlessKeys = {
    privateKey: argv.private_key,
    pubKey: argv.pub_key
  }
  console.log "pub_key looks like this: " + argv.pub_key
  sessionless.getKeys = () -> sessionlessKeys

  app.get '/plugin/signature/owner-key', (req, res) -> 
    site = 'http://' + decodeURIComponent req.query.site
    console.log 'fetching key from ', site
    resp = fetch(site + '/plugin/signature/key')
      .then (resp) ->
        resp.json()
          .then (keyJSON) ->
            res.send keyJSON
          .catch (err) -> 
            throw new Error 'malformed key response'
      .catch (err) ->
        console.warn err
        res.sendStatus 404

  app.get '/plugin/signature/key', (req, res) ->
    if !sessionlessKeys.pubKey 
      res.sendStatus(404)
    console.log 'sessionlessKeys', sessionlessKeys
    res.json {public: sessionlessKeys.pubKey, algo:'ecdsa'}

  app.get '/plugin/signature/verify', (req, res) ->
    console.log 'query is: ', req.query
    signature = req.query.signature
    message = req.query.message
    pubKey = req.query.pubKey
    verified = sessionless.verifySignature signature, message, pubKey
    res.send '' + verified

  app.get '/plugin/signature/persist', (req, res) ->
    console.log "starting persist"
    noop = () -> {}
    wikiHome = "/Users/zachbabb/.wiki"
    files = fs.readdirSync "#{wikiHome}/pages"
    console.log "files", files
    wikiObj = {}
    files.forEach (file) ->
      wikiObj[file] = fs.readFileSync "#{wikiHome}/pages/#{file}", {encoding: 'utf-8'}

    console.log "persisting #{Object.sessionlessKeys(wikiObj).length} files"

    payload = {timestamp: new Date().getTime() + "", pubKey: sessionlessKeys.pubKey, hash: "fedwiki", bdo: wikiObj}
    console.log(typeof payload.timestamp)
    console.log(typeof sessionlessKeys.pubKey)
    console.log(typeof payload.hash)
    message = "#{payload.timestamp}#{payload.pubKey}#{payload.hash}"
    console.log message
    console.log message.length
    console.log sessionlessKeys.privateKey
    # sessionless.getKeys().then (_sessionlessKeys) -> 
    console.log "the received sessionlessKeys are: #{JSON.stringify(sessionless.getKeys())}"
    console.log sessionlessKeys.privateKey
    console.log typeof sessionlessKeys.privateKey
    sessionless.sign(message).then (signature) ->
      payload.signature = signature
      console.log "Sending to allyabase with signature", payload.signature
      console.log "is this signature even cool?", sessionless.verifySignature(signature, message, sessionless.getKeys().pubKey)
      fetch("https://dev.bdo.allyabase.com/user/create", {method: "put", body: JSON.stringify(payload), headers: {"Content-Type": "application/json"}}).then (resp) ->
        console.log "received status from allyabase", resp.status
        resp.json().then (user) ->
          console.log "received response from allyabase", user
          uuid = user.uuid
          res.send({uuid: uuid})
     
    # noop = () -> {}
    # bdoPromise = bdo.createUser 'foo', wikiObj, noop, sessionless.getKeys
    # bdoPromise.then (uuid) ->
      # console.log "you can get your wiki at: #{uuid}"


  app.get '/plugin/signature/:thing', (req, res) ->
    console.log "got a request to sign #{req.params.thing} with #{JSON.stringify(sessionlessKeys)}"
    if !sessionlessKeys.privateKey 
      console.log "there's no private key"
      res.sendStatus(404)
    sessionless.sign(req.params.thing)
      .then (signature) -> 
        console.log 'signature', signature
        res.json {signature}
        return
      .catch (err) ->
        console.error err
        res.sendStatus(404)

)

module.exports = {startServer}
