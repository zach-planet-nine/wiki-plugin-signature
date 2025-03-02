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
  
  signatureKeys = {
    privateKey: argv.private_key,
    pubKey: argv.pub_key
  }
  console.log "pub_key looks like this: " + argv.pub_key
  console.log "private_key looks like this: " + argv.private_key
  sessionless.getKeys = () -> signatureKeys

  app.get '/plugin/signature2/owner-key', (req, res) -> 
    site = 'http://' + decodeURIComponent req.query.site
    console.log 'fetching key from ', site
    resp = fetch(site + '/plugin/signature2/key')
      .then (resp) ->
        resp.json()
          .then (keyJSON) ->
            res.send keyJSON
          .catch (err) -> 
            throw new Error 'malformed key response'
      .catch (err) ->
        console.warn err
        res.sendStatus 404

  app.get '/plugin/signature2/key', (req, res) ->
    if !signatureKeys.pubKey 
      res.sendStatus(404)
    console.log 'signatureKeys', signatureKeys
    console.log "argv.private_key", argv.private_key
    res.json {public: signatureKeys.pubKey, algo:'ecdsa'}

  app.get '/plugin/signature2/verify', (req, res) ->
    console.log 'query is: ', req.query
    signature = req.query.signature
    message = req.query.message
    pubKey = req.query.pubKey
    verified = sessionless.verifySignature signature, message, pubKey
    res.send '' + verified

  app.get '/plugin/signature2/persist', (req, res) ->
    console.log "starting persist"
    noop = () -> {}
    wikiHome = "/Users/zachbabb/.wiki"
    files = fs.readdirSync "#{wikiHome}/pages"
    console.log "files", files
    wikiObj = {}
    files.forEach (file) ->
      wikiObj[file] = fs.readFileSync "#{wikiHome}/pages/#{file}", {encoding: 'utf-8'}

    console.log "persisting #{Object.keys(wikiObj).length} files"

    payload = {timestamp: new Date().getTime() + "", pubKey: signatureKeys.pubKey, hash: "fedwiki", bdo: wikiObj}
    console.log(typeof payload.timestamp)
    console.log(typeof signatureKeys.pubKey)
    console.log(typeof payload.hash)
    message = "#{payload.timestamp}#{payload.pubKey}#{payload.hash}"
    console.log message
    console.log message.length
    console.log signatureKeys.privateKey
    # sessionless.getKeys().then (_signatureKeys) -> 
    console.log "the received signatureKeys are: #{JSON.stringify(sessionless.getKeys())}"
    console.log signatureKeys.privateKey
    console.log typeof signatureKeys.privateKey
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


  app.get '/plugin/signature2/:thing', (req, res) ->
    console.log "got a request to sign #{req.params.thing} with #{JSON.stringify(signatureKeys)}"
    if !signatureKeys.privateKey 
      console.log "there's no private key"
      res.sendStatus(404)
    _getKeys = sessionless.getKeys
    console.log "argv.private_key is still: #{argv.private_key}"
    sessionless.getKeys = () -> 
      {
        privateKey: argv.private_key,
        pubKey: argv.pub_key
      } 
    sessionless.sign(req.params.thing)
      .then (signature) -> 
        console.log 'signature', signature
        res.json {signature}
        return
      .catch (err) ->
        console.error err
        res.sendStatus(404)
      .finally () ->
        sessionless.getKeys = _getKeys

)

module.exports = {startServer}
