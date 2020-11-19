var testtxb = {
    "keyset": {
        "pred": "keys-all",
        "keys": [
            "fce0a17ac6a9ad592d344da74a84d3516330f4580689797189a89b881f904d51"
        ]
    },
    "account": "alice",
    "chain": "0"
};

Vue.component('btc-address-input', {
    props: ['value'],
    template: `
      <div v-bind:class="this.isError() ? 'attempted-submit' : ''">
        <input type="text"
               ref="rawAddress"
               v-bind:value="value"
               v-on:input="$emit('input', $event.target.value)"
               v-bind:class="this.isError() ? 'field-error' : ''">
      </div>
    `,
    methods: {
        isValidBtcAddress(v) {
            if ( v != null ) {
                var addr = v.match(/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/);
                return addr != null;
            } else {
                return false;
            }
        },
        isError: function() {
            const err = !this.isValidBtcAddress(this.value);
            const res = err && this.$refs.rawAddress != undefined && this.$refs.rawAddress.value != null && this.$refs.rawAddress.value != '';
            return res;
        }
    }
});

Vue.component('txb-input', {
    props: ['value'],
    template: `
      <div v-bind:class="this.isError() ? 'attempted-submit' : ''">
        <input type="text"
               ref="rawTxb"
               :value="txbToString(value)"
               @input="updateInput()"
               v-bind:class="this.isError() ? 'field-error' : ''">
      </div>
    `,
    methods: {
        stringToTxb(v) {
            var txb = null;
            try {
                var raw = JSON.parse(v);
                if ( raw != null ) {
                  if ( typeof raw.account === "undefined" ) {
                      throw "no account";
                  }
                    if ( typeof raw.keyset === "undefined" ) {
                        throw "no keyset";
                    }
                  if ( typeof raw.keyset.pred === "undefined" ) {
                      throw "no pred";
                  }
                  if ( typeof raw.keyset.keys === "undefined" ) {
                      throw "no keys";
                  }
                    txb = { "account": raw.account,
                            "keyset": raw.keyset
                          };
                }
            } catch (e) {
                if ( v != null ) {
                    var pubkey = v.match(/^[a-fA-F0-9]{64}$/);
                    if ( pubkey != null ) {
                        txb = { "account": v,
                                "keyset": { "keys": [v], "pred": "keys-all" }
                              };
                    }
                }
            }
            return txb;
        },
        txbToString(txb) {
            if ( txb == null )
                return '';
            else if ( txb.keyset.pred == "keys-all" && txb.keyset.keys.length == 1 && txb.keyset.keys[0] == txb.account ) {
                return txb.account;
            } else {
                return JSON.stringify(txb);
            }
        },
        updateInput() {
            this.$emit('input', this.stringToTxb(this.$refs.rawTxb.value));
        },
        isError: function() {
            return this.value == null && this.$refs.rawTxb != undefined && this.$refs.rawTxb.value != null && this.$refs.rawTxb.value != '';
        }
    }
});

Vue.component('site-nav', {
    props: [],
    template: `
		    <div class="nav-container">
            <nav class="absolute bg-dark fixed outOfSight scrolled">
		            <div class="nav-bar">
		                <div class="module left">
		                    <a href="index.html" class="inner-link">
                            <h3 style="height:55px;line-height:55px;">KBridge</h3>
		                    </a>
		                </div>
		                <div class="module widget-handle mobile-toggle right visible-sm visible-xs">
		                    <i class="ti-menu"></i>
		                </div>
		                <div class="module-group right">
		                    <div class="module left">
		                        <ul class="menu">
                                <li class="vpf">
		                                <a href="index.html">What is a bridge?</a>
		                            </li>
                                <li class="vpf">
		                                <a href="proof-of-assets.html">Proof of Assets</a>
		                            </li>
                                <li class="vpf">
		                                <a href="get-tokens.html">Get KTokens</a>
		                            </li>
                                <li class="vpf">
		                                <a href="redeem-tokens.html">Redeem KTokens</a>
		                            </li>
		                        </ul>
		                    </div>
		                </div>
		            </div>
		        </nav>
		    </div>
    `
});

Vue.component('site-footer', {
    props: [],
    template: `
      <footer class="footer-2 bg-dark text-center-xs">
			    <div class="container">
			        <div class="row">
			            <div class="col-sm-4">
                      <h3 style="height:55px;line-height:55px;">KBridge</h3>
			                <!-- <a href="#"><div class="vnu"><img class="image-xxs fade-half" alt="Pic" src="img/logo-light.png"></div></a> -->
			            </div>

			            <div class="col-sm-4 text-center">
			                <span class="fade-half">
			                    © Copyright 2020 KBridge - All Rights Reserved
			                </span>
			            </div>

			            <div class="col-sm-4 text-right text-center-xs">
			                <ul class="list-inline social-list">
			                    <li><a href="#"><i class="ti-twitter-alt"></i></a></li>
			                    <li><a href="#"><i class="ti ti-github"></i></a></li>
			                </ul>
			            </div>
			        </div>
			    </div>
			</footer>
    `
});

Vue.component('accordion', {
    props: {
        title: {
            type: String,
            required: true
        }
    },
    template: `
      <div>
          <div class="input-with-label text-left">
              <span v-on:click="open = !open" class="cursor-clickable">{{title}}
                  <i v-bind:class="open ? 'far fa-caret-square-down' : 'far fa-caret-square-right'"></i>
              </span>
          </div>

          <div v-bind:class="open ? '' : 'invisible'">
              <slot></slot>
          </div>
          <br/>
      </div>
    `,
    data() {
        return {
            open: false
        };
    }
});

const allTokens = {
    "BTC" : { "fee": 0.002, "min": 0.01, "address": "35hK24tcLEWcgNA4JxpvbkNkoAcDGqQPsP" },
    "ETH" : { "fee": 0.002, "min": 0.3, "address": "not implemented yet" },
    "DAI" : { "fee": 0.002, "min": 100, "address": "not implemented yet" },
}

var app = new Vue({
    el: '#app'
});

var mintApp = new Vue({
    el: '#mintApp',
    data: {
        stage: 0,
        tokens: allTokens,
        tokenType: "BTC",
        node: "http://localhost:4443",
        txb: null,
        cmd: null,
        requestId: null,
        errMsg: null
    },
    computed: {
        sendToAddress() {
            return this.tokens[this.tokenType]["address"];
        },
        txFeePercent() {
            return this.tokens[this.tokenType]["fee"] * 100.0;
        },
        txMin() {
            return this.tokens[this.tokenType]["min"];
        }
    },
    methods: {
        prepareMintRequest() {
            const d = new Date();
            const dStr = d.toISOString();
            const code = '(kbtc.buy-token "' + this.txb.account + '" (read-keyset "ks") "' + dStr + '")';
            this.cmd = {
                    "pactCode": code,
                    "envData": {"ks": this.txb.keyset}
            };
            // TODO properly get the chainwebversion and the chain ID
            //var res = Pact.fetch.local(this.cmd, this.node + '/chainweb/0.0/mainnet01/chain/0/pact');
            var res = Pact.fetch.local(this.cmd, this.node);
            res.then(v => {this.requestId = v.result.data['request-id']; this.stage += 1;},
                     e => {this.errMsg = 'Error contacting node (' + e + ')'; });
        },
        sendMintRequest() {
            Pact.fetch.send(this.cmd, this.node);
            this.stage += 1;
        }
    }
});

var redeemApp = new Vue({
    el: '#redeemApp',
    data: {
        stage: 0,
        tokens: allTokens,
        tokenType: "BTC",
        node: "http://localhost:4443",
        sendingAccount: null,
        receivingAddress: null,
        amount: null,
        sendMax: false,
        cmd: null,
        code: null,
        meta: null,
        accountDetails: null,
        errMsg: null,
        publicKey: null,
        selectedKeys: [],
        hash: null,
        sig: null,
        sigs: [],
        localStatus: null,
        sendStatus: null,
        date: null,
        //CHANGE
        networkId: null,
        sendCmd: null,
        reqKey: null,
        reqId: null
    },
    computed: {
        txFeePercent() {
            return this.tokens[this.tokenType]["fee"] * 100.0;
        },
        txMin() {
            return this.tokens[this.tokenType]["min"];
        }
    },
    methods: {
        localReady() {
            if ( this.sigs ) {
              const filt = this.sigs.filter(sig => sig.length === 128 || sig.length === 64)
              return this.txReady()
                && filt.length === this.selectedKeys.length
            } else {
              return false
            }
        },
        txReady() {
          return this.receivingAddress != null
              && this.sendingAccount != null
              && this.errMsg === null
              && !isNaN(this.amount)
              && this.selectedKeys.length > 0
              && this.receivingAddress.match(/^[13][a-km-zA-HJ-NP-Z1-9]{25,34}$/)
              && ((this.amount != null && this.amount != '') || this.sendMax);
        },
        maxAmount() {
          this.amount = this.accountDetails.balance;
        },
        incStage() {
          this.stage += 1;
        },
        decStage() {
          this.stage -= 1;
          this.errMsg = null;
        },
        convertDecimal(decimal) {
          decimal = decimal.toString();
          if (decimal[0] === ".") {return "0" + decimal}
          if (decimal.includes('.')) { return decimal }
          if ((decimal / Math.floor(decimal)) === 1) {
            decimal = decimal + ".0"
          }
          return decimal
        },
        mkReq(cmd) {
         console.log(cmd)
         return {
             headers: {
                 "Content-Type": "application/json"
             },
             method: "POST",
             body: JSON.stringify(cmd)
         };
        },
        mkSig(kp){
          var cmdJSON = {
            networkId: this.networkId,
            payload: {
              exec: {
                data: {},
                code: this.code
              }
            },
            signers: this.selectedKeys.map((key, i) => { return { publicKey: key, secretKey: null, clist: [{name: "coin.GAS", args: []}] } }),
            meta: this.meta,
            nonce: this.date
          };
          var cmd = JSON.stringify(cmdJSON);
          var sig = Pact.crypto.sign(cmd, kp).sig;
          return sig
        },
        async prepareRedeem() {
            if (!this.txReady() ) { return }
            this.code = `(kbtc.sell-token ${JSON.stringify(this.receivingAddress)} ${JSON.stringify(this.date)} ${JSON.stringify(this.sendingAccount)} ${this.convertDecimal(this.amount)})`
            this.meta = Pact.lang.mkMeta(this.sendingAccount, "0", 0.00001, 600, parseFloat(this.date)-60, 28800);
            this.cmd = Pact.simple.exec.createCommand(
              this.selectedKeys.map((key, i) => { return { publicKey: key, secretKey: null, clist: [] } }),
              this.date,
              this.code,
              {},
              this.meta,
              this.networkId
            )
            this.hash = this.cmd.cmds[0].hash
            this.sigs = []
        },
        async localRedeem() {
          const c = this.cmd.cmds[0].cmd;
          var theSigs = [];
          for ( var i = 0; i < this.selectedKeys.length; i++ ) {
            const pk = this.selectedKeys[i];
            var sigOrPrivateKey = this.sigs[i];
            if (sigOrPrivateKey.length === 64) {
              const kp = {
                publicKey: pk,
                secretKey: sigOrPrivateKey
              }
              theSigs.push({sig: Pact.crypto.sign(c, kp).sig});
            } else {
              theSigs.push({sig: sigOrPrivateKey});
            }
          }
          console.log(this.cmd)
          const finalCmd = {
            hash: this.hash,
            cmd: c,
            sigs: theSigs
          };
          try {
            const local = await fetch(`${this.node}/api/v1/local`, this.mkReq(finalCmd));
            const res = await local.json()
            console.log(res.result)
            if (res.result.status === 'success') {
              this.localStatus = 'success'
              this.sendCmd = { cmds: [finalCmd] }
            } else {
              this.localStatus = 'failure'
              this.errMsg = res.result.error.message;
            }
          } catch (e) {
            this.localStatus = 'failure'
            console.log(e)
          }
        },
        async sendRedeem(){
          try {
            const sendRes = await fetch(`${this.node}/api/v1/send`, this.mkReq(this.sendCmd));
            const sendJson = await sendRes.json();
            this.reqKey = sendJson.requestKeys[0]
            this.incStage();
            await this.listenRedeem()
          } catch (e) {
            console.log(e)
          }
        },
        async listenRedeem() {
          try {
            this.sendStatus = 'pending'
            const res = await Pact.fetch.listen({listen: this.reqKey}, this.node)
            if ( res.result.status === 'success' ) {
              this.sendStatus = 'success'
              this.reqId = res.result.data["request-id"]
            } else {
              this.sendStatus = 'failure'
            }
          } catch (e) {
            console.log(e)
            this.sendStatus = 'failure'
          }

        },
        async getAccount() {
          try {
            var acctCmd = {
              "pactCode": `(kbtc.details ${JSON.stringify(this.sendingAccount)})`
            }
            var res  = await Pact.fetch.local(acctCmd, this.node)
            if (res.result.status === 'success') {
              this.accountDetails = res.result.data;
              this.errMsg = null;
            } else {
              this.errMsg = 'account does not exist';
              this.accountDetails = null;
            }
          } catch (e) {
            this.errMsg = 'account does not exist'
            this.accountDetails = null;
          }
        }
    },
    beforeMount(){
      const d = new Date();
      this.date = d.toISOString();
   },
});

var poaApp = new Vue({
  el: '#poaApp',
  data: {
    btcAmount: "loading...",
    btcAddress: allTokens["BTC"]["address"],
    kbtcAmount: "loading...",
    kbtcAddress: "kbtc",
    node: "http://localhost:4443",
  },
  computed: {
      btcLink() {
          return "https://blockstream.info/address/" + this.btcAddress;
      },
      kbtcLink() {
          return "https://explorer.chainweb.com/mainnet/chain/0/block/YoGUKi0Tq2Owg0nL7PDkcVLj6GTBSGCEUB-NQmmQn7U=/txs";
      }
  },
  methods: {
    async getBtcBalance() {
      try {
        //var res = await fetch('https://blockchain.info/de/q/addressbalance/' + this.btcAddress);
        // Hard code this for now so that we have a balance but aren't at risk of people sending to the wrong address.
        var res = await fetch('https://blockchain.info/de/q/addressbalance/35hK24tcLEWcgNA4JxpvbkNkoAcDGqQPsP');
        var amountSats = await res.json()
        this.btcAmount = amountSats / 1000000
      } catch (e) {
        this.btcAmount = 'Error contacting node (' + e + ')'
      }

    },
    async getKbtcCirculation() {
      //TODO implement get-total in smart contract
      const code = '(' + this.kbtcAddress + ".get-supply" + ')';
      const cmd = {
        "pactCode": code
      }
      try {
        var res = await Pact.fetch.local(cmd, this.node);
        this.kbtcAmount = res.result.data['supply']
      } catch (e) {
        this.kbtcAmount = 'Error contacting node (' + e + ')';
      }
    }
  },
  beforeMount(){
    this.getKbtcCirculation();
    this.getBtcBalance();
 },
})
