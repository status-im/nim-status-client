(function(){
  // Based on
  // https://github.com/status-im/status-react/blob/f9fb4d6974138a276b0cdcc6e4ea1611063e70ca/resources/js/provider.js

  if(typeof EthereumProvider === "undefined"){
    let callbackId = 0;
    let callbacks = {};

    const onMessage = function(message){
      const data = JSON.parse(message);
      const id = data.messageId;
      const callback = callbacks[id];

      if (callback) {
        if (data.type === "api-response") {
          if (data.permission == "qr-code") {
            qrCodeResponse(data, callback); // TODO: are we going to support the qr-code permission?
          } else if (data.isAllowed) {
            if (data.permission == "web3") {
              window.statusAppcurrentAccountAddress = data.data[0];
            }
            callback.resolve(data.data);
          } else {
            callback.reject(new UserRejectedRequest());
          }
        } else if (data.type === "web3-send-async-callback") {
          if (callback.beta) {
            if (data.error) {
              if (data.error.code == 4100) {
                callback.reject(new Unauthorized());
              } else {
                callback.reject(data.error);
              }
            } else {
              callback.resolve(data.result.result);
            }
          } else if (callback.results) {
            callback.results.push(data.error || data.result);
            if (callback.results.length == callback.num)
              callback.callback(undefined, callback.results);
          } else {
            callback.callback(data.error, data.result);
          }
        }
      }
    }
    
    let backend;
    new QWebChannel(qt.webChannelTransport, function(channel) {
      backend = channel.objects.backend;
      backend.web3Response.connect(onMessage);
    });

    const bridgeSend = data => backend.postMessage(JSON.stringify(data));

    let history = window.history;
    let pushState = history.pushState;
    history.pushState = function(state) {
      setTimeout(function () {
        bridgeSend({
          type: "history-state-changed",
          navState: { url: location.href, title: document.title },
        });
      }, 100);
      return pushState.apply(history, arguments);
    };

    function sendAPIrequest(permission, params) {
      const messageId = callbackId++;
      params = params || {};  
      
      bridgeSend({
          type: 'api-request',
          permission: permission,
          messageId: messageId,
          params: params
      });  
      
      return new Promise(function (resolve, reject) {
        params['resolve'] = resolve;
        params['reject'] = reject;
        callbacks[messageId] = params;
      });
    }

    function qrCodeResponse(data, callback){
      const result = data.data;
      const regex = new RegExp(callback.regex);
      if (!result) {
        if (callback.reject) {
          callback.reject(new Error("Cancelled"));
        }
      } else if (regex.test(result)) {
        if (callback.resolve) {
          callback.resolve(result);
        }
      } else {
        if (callback.reject) {
          callback.reject(new Error("Doesn't match"));
        }
      }
    }

    function Unauthorized() {
      this.name = "Unauthorized";
      this.id = 4100;
      this.code = 4100;
      this.message = "The requested method and/or account has not been authorized by the user.";
    }
    Unauthorized.prototype = Object.create(Error.prototype);

    function UserRejectedRequest() {
      this.name = "UserRejectedRequest";
      this.id = 4001;
      this.code = 4001;
      this.message = "The user rejected the request.";
    }
    UserRejectedRequest.prototype = Object.create(Error.prototype);

    function web3Response (payload, result){
      return {
        id: payload.id,
        jsonrpc: "2.0",
        result: result
      };
    }

    function getSyncResponse (payload) {
        if (payload.method == "eth_accounts" && (typeof window.statusAppcurrentAccountAddress !== "undefined")) {
            return web3Response(payload, [window.statusAppcurrentAccountAddress])
        } else if (payload.method == "eth_coinbase" && (typeof window.statusAppcurrentAccountAddress !== "undefined")) {
            return web3Response(payload, window.statusAppcurrentAccountAddress)
        } else if (payload.method == "net_version" || payload.method == "eth_chainId"){
            return web3Response(payload, backend.networkId)
        } else if (payload.method == "eth_uninstallFilter"){
            return web3Response(payload, true);
        } else {
            return null;
        }
    }

    var StatusAPI = function () {};

    StatusAPI.prototype.getContactCode = function () {
        return sendAPIrequest('contact-code');
    };

    var EthereumProvider = function () {};

    EthereumProvider.prototype.isStatus = true;
    EthereumProvider.prototype.status = new StatusAPI();
    EthereumProvider.prototype.isConnected = function () { return true; };

    EthereumProvider.prototype.enable = function () {
        return sendAPIrequest('web3');
    };

    EthereumProvider.prototype.scanQRCode = function (regex) {
        return sendAPIrequest('qr-code', {regex: regex});
    };

    EthereumProvider.prototype.request = function (requestArguments) {
      if (!requestArguments) return new Error("Request is not valid.");
        
      const method = requestArguments.method;

      if (!method) return new Error("Request is not valid.");

      //Support for legacy send method
      if (typeof method !== "string") return this.sendSync(method);

      if (method == "eth_requestAccounts") return sendAPIrequest("web3");

      const syncResponse = getSyncResponse({ method: method });
      if (syncResponse) {
        return new Promise(function (resolve, reject) {
          resolve(syncResponse.result);
        });
      }

      const messageId = callbackId++;
      const payload = {
        id: messageId,
        jsonrpc: "2.0",
        method: method,
        params: requestArguments.params,
      };  

      bridgeSend({
        type: "web3-send-async-read-only",
        messageId: messageId,
        payload: payload,
      });  

      return new Promise(function (resolve, reject) {
        callbacks[messageId] = {
          beta: true,
          resolve: resolve,
          reject: reject,
        };
      });
    };

    // (DEPRECATED) Support for legacy send method
    EthereumProvider.prototype.send = function (method, params = []) {
      return this.request({method: method, params: params});
    }

    // (DEPRECATED) Support for legacy sendSync method
    EthereumProvider.prototype.sendSync = function (payload) {
      if (payload.method == "eth_uninstallFilter") {
        this.sendAsync(payload, function (res, err) {});
      }
      const syncResponse = getSyncResponse(payload);
      if (syncResponse) return syncResponse;
      
      return web3Response(payload, null);
    };

    // (DEPRECATED) Support for legacy sendAsync method
    EthereumProvider.prototype.sendAsync = function (payload, callback) {
      const syncResponse = getSyncResponse(payload);
      if (syncResponse && callback) {
        callback(null, syncResponse);
      } else {
        const messageId = callbackId++;

        if (Array.isArray(payload)) {
          callbacks[messageId] = {
            num: payload.length,
            results: [],
            callback: callback,
          };

          for (let i in payload) {
            bridgeSend({
              type: "web3-send-async-read-only",
              messageId: messageId,
              payload: payload[i],
            });
          }
        } else {
          callbacks[messageId] = { callback: callback };
          bridgeSend({
            type: "web3-send-async-read-only",
            messageId: messageId,
            payload: payload,
          });
        }
      }
    };
  }

  window.ethereum = new EthereumProvider();
})();