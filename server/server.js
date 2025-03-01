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
    var app, argv, idFile, keys;
    app = params.app;
    argv = params.argv;
    // this is meant to be .wiki/status/owners.json, but any valid path with the correct json will work
    idFile = argv.id || '';
    keys = {
      privateKey: argv.private_key,
      pubKey: argv.pub_key
    };
    console.log("pub_key looks like this: " + argv.pub_key);
    sessionless.getKeys = function() {
      return keys;
    };
    app.get('/plugin/signature/owner-key', function(req, res) {
      var resp, site;
      site = 'http://' + decodeURIComponent(req.query.site);
      console.log('fetching key from ', site);
      return resp = fetch(site + '/plugin/signature/key').then(function(resp) {
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
    app.get('/plugin/signature/key', function(req, res) {
      if (!keys.pubKey) {
        res.sendStatus(404);
      }
      console.log('keys', keys);
      return res.json({
        public: keys.pubKey,
        algo: 'ecdsa'
      });
    });
    app.get('/plugin/signature/verify', function(req, res) {
      var message, pubKey, signature, verified;
      console.log('query is: ', req.query);
      signature = req.query.signature;
      message = req.query.message;
      pubKey = req.query.pubKey;
      verified = sessionless.verifySignature(signature, message, pubKey);
      return res.send('' + verified);
    });
    app.get('/plugin/signature/persist', function(req, res) {
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
        pubKey: keys.pubKey,
        hash: "fedwiki",
        bdo: wikiObj
      };
      console.log(typeof payload.timestamp);
      console.log(typeof keys.pubKey);
      console.log(typeof payload.hash);
      message = `${payload.timestamp}${payload.pubKey}${payload.hash}`;
      console.log(message);
      console.log(message.length);
      console.log(keys.privateKey);
      // sessionless.getKeys().then (_keys) -> 
      console.log(`the received keys are: ${JSON.stringify(sessionless.getKeys())}`);
      console.log(keys.privateKey);
      console.log(typeof keys.privateKey);
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
    return app.get('/plugin/signature/:thing', function(req, res) {
      console.log(`got a request to sign ${req.params.thing} with ${JSON.stringify(keys)}`);
      if (!keys.privateKey) {
        console.log("there's no private key");
        res.sendStatus(404);
      }
      return sessionless.sign(req.params.thing).then(function(signature) {
        console.log('signature', signature);
        res.json({signature});
      }).catch(function(err) {
        console.error(err);
        return res.sendStatus(404);
      });
    });
  };

  module.exports = {startServer};

}).call(this);
