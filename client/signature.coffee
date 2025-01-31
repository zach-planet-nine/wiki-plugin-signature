
crypto = require 'crypto'
fs = require 'fs'
path = require 'path'
sessionless = require 'sessionless-node'

keys = {}

fs.exists idfile (exists) ->
  if exists
    fs.readFile(idFile, (err, data) ->
      if err then return cb err
      keys = JSON.parse(data))
      console.log 'keys', keys

expand = (text) ->
  text
    .replace /&/g, '&amp;'
    .replace /</g, '&lt;'
    .replace />/g, '&gt;'

page = ($item) ->
  $item.parents('.page').data('data')

check = ($item) ->
  # https://www.npmjs.com/package/object-hash ?
  # https://docs.nodejitsu.com/articles/cryptography/how-to-use-crypto-module/

  sum = crypto.createHash 'md5'
  for item in page($item).story
    if item.type == 'signature'
      sum.update item.text
    else
      sum.update JSON.stringify(item)
  sum.digest 'hex'

validateSignature = (sigObj) -> 
  algo = sigObj.algo
  
  switch algo
    case 'trivial': return true
      break
    case 'ecdsa': 
      timestamp = sigObj.timestamp
      rev = sigObj.rev
      algo = sigObj.algo 
      sum = sigObj.sum
      message = timestamp + rev + algo + sum

      signature = sigObj.signature

      return sessionless.verifySignature(signature, message, keys.pubKey)

emit = ($item, item) ->

  sum = check $item

  status = (sigs) ->
    if validateSignature sigs[sum]
      "<td style=\"color: #3f3; text-align: right;\">valid"
    else
      "<td style=\"color: #f88; text-align: right;\">invalid"


  report = ->
    for site, sigs of item.signatures || {}
      "<tr>#{status sigs}<td>#{site}"

  $item.append """
    <div style="background-color:#eee; padding:8px;">
      <center>
        #{expand item.text}
        <table style="background-color:#f8f8f8; margin:8px; padding:8px; min-width:70%">
          #{report().join('')}
        </table>
        <button>sign</button>
      </center>
    </div>
  """

bind = ($item, item) ->

  update = ->
    wiki.pageHandler.put $item.parents('.page:first'),
      type: 'edit',
      id: item.id,
      item: item

  $item.dblclick -> wiki.textEditor $item, item

  $item.find('button').click ->
    date = new Date()
    timestamp = new Date().getTime() + ''
    rev = page($item).journal.length-1
#    algo = 'trivial'
    algo = 'ecdsa'
    sum = check $item
    host = location.host
    signature = await sessionless.sign(timestamp + rev + algo + sum + signature)
    item.signatures ||= {}
    item.signatures[location.host] ||= {}
    item.signatures[location.host][sum] = {date, timestamp, rev, algo, sum, signature}
    $item.empty()
    emit $item, item
    bind $item, item
    update()


window.plugins.signature = {emit, bind} if window?
module.exports = {expand} if module?

