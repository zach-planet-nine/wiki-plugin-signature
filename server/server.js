(function() {
  // signature plugin, server-side component
  // These handlers are launched with the wiki server. 
  var fs, path, sessionless, startServer;

  fs = require('fs');

  path = require('path');

  sessionless = require('sessionless-node');

  // bdo = require 'bdo-js' // allyabase client libs need to be adapted for commonjs, and I want
  //                          // to think about the best way of doing that
  startServer = function(params) {
    var app, argv, idFile, signatureKeys;
    app = params.app;
    argv = params.argv;
    // this is meant to be .wiki/status/owners.json, but any valid path with the correct json will work
    idFile = argv.id || '';
    signatureKeys = {
      privateKey: argv.private_key,
      pubKey: argv.pub_key
    };
    console.log("pub_key looks like this: " + argv.pub_key);
    console.log("private_key looks like this: " + argv.private_key);
    sessionless.getKeys = function() {
      return signatureKeys;
    };
    app.get('/plugin/signature2/owner-key', function(req, res) {
      var resp, site;
      site = 'http://' + decodeURIComponent(req.query.site);
      console.log('fetching key from ', site);
      return resp = fetch(site + '/plugin/signature2/key').then(function(resp) {
        return resp.json().then(function(keyJSON) {
          return res.send(keyJSON);
        }).catch(function(err) {
          throw new Error('malformed key response');
        });
      }).catch(function(err) {
        console.warn(err);
        return res.sendStatus(404);
      });
    });
    app.get('/plugin/signature2/key', function(req, res) {
      if (!signatureKeys.pubKey) {
        res.sendStatus(404);
      }
      console.log('signatureKeys', signatureKeys);
      console.log("argv.private_key", argv.private_key);
      return res.json({
        public: signatureKeys.pubKey,
        algo: 'ecdsa'
      });
    });
    app.get('/plugin/signature2/verify', function(req, res) {
      var message, pubKey, signature, verified;
      console.log('query is: ', req.query);
      signature = req.query.signature;
      message = req.query.message;
      pubKey = req.query.pubKey;
      verified = sessionless.verifySignature(signature, message, pubKey);
      return res.send('' + verified);
    });
    app.get('/plugin/signature2/persist', function(req, res) {
      var files, message, noop, payload, wikiHome, wikiObj;
      console.log("starting persist");
      noop = function() {
        return {};
      };
      wikiHome = "/Users/zachbabb/.wiki";
      files = fs.readdirSync(`${wikiHome}/pages`);
      console.log("files", files);
      wikiObj = {};
      files.forEach(function(file) {
        return wikiObj[file] = fs.readFileSync(`${wikiHome}/pages/${file}`, {
          encoding: 'utf-8'
        });
      });
      console.log(`persisting ${Object.keys(wikiObj).length} files`);
      payload = {
        timestamp: new Date().getTime() + "",
        pubKey: signatureKeys.pubKey,
        hash: "fedwiki",
        bdo: wikiObj
      };
      console.log(typeof payload.timestamp);
      console.log(typeof signatureKeys.pubKey);
      console.log(typeof payload.hash);
      message = `${payload.timestamp}${payload.pubKey}${payload.hash}`;
      console.log(message);
      console.log(message.length);
      console.log(signatureKeys.privateKey);
      // sessionless.getKeys().then (_signatureKeys) -> 
      console.log(`the received signatureKeys are: ${JSON.stringify(sessionless.getKeys())}`);
      console.log(signatureKeys.privateKey);
      console.log(typeof signatureKeys.privateKey);
      return sessionless.sign(message).then(function(signature) {
        payload.signature = signature;
        console.log("Sending to allyabase with signature", payload.signature);
        console.log("is this signature even cool?", sessionless.verifySignature(signature, message, sessionless.getKeys().pubKey));
        return fetch("https://dev.bdo.allyabase.com/user/create", {
          method: "put",
          body: JSON.stringify(payload),
          headers: {
            "Content-Type": "application/json"
          }
        }).then(function(resp) {
          console.log("received status from allyabase", resp.status);
          return resp.json().then(function(user) {
            var uuid;
            console.log("received response from allyabase", user);
            uuid = user.uuid;
            return res.send({
              uuid: uuid
            });
          });
        });
      });
    });
    
    // noop = () -> {}
    // bdoPromise = bdo.createUser 'foo', wikiObj, noop, sessionless.getKeys
    // bdoPromise.then (uuid) ->
    // console.log "you can get your wiki at: #{uuid}"
    return app.get('/plugin/signature2/:thing', function(req, res) {
      var _getKeys;
      console.log(`got a request to sign ${req.params.thing} with ${JSON.stringify(signatureKeys)}`);
      if (!signatureKeys.privateKey) {
        console.log("there's no private key");
        res.sendStatus(404);
      }
      _getKeys = sessionless.getKeys;
      console.log(`argv.private_key is still: ${argv.private_key}`);
      sessionless.getKeys = function() {
        return {
          privateKey: argv.private_key,
          pubKey: argv.pub_key
        };
      };
      return sessionless.sign(req.params.thing).then(function(signature) {
        console.log('signature', signature);
        res.json({signature});
      }).catch(function(err) {
        console.error(err);
        return res.sendStatus(404);
      }).finally(function() {
        return sessionless.getKeys = _getKeys;
      });
    });
  };

  module.exports = {startServer};

}).call(this);
