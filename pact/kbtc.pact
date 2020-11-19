(namespace "user")
(define-keyset 'kbtc-admin (read-keyset 'kbtc-admin))

(module kbtc GOVERNANCE

  (implements fungible-v2)

  ; --------------------------------------------------------------------------
  ; Schemas and Tables

  (defschema token-schema
    @doc " An account, holding a token balance. \
         \ \
         \ ROW KEY: account-id. "
    @model [ (invariant (>= balance 0.0)) ]
    balance:decimal
    guard:guard
  )
  (deftable token-table:{token-schema})

  (defschema stats-schema
    @doc " Keep track of ciculating supply "
    @model [ (invariant (>= supply 0.0)) ]
    supply:decimal
  )
  (deftable stats:{stats-schema})

  (defschema buy-schema
    @doc " A request specifing the amount and accounts. \
         \ expiration is block-time + 24 hours \
         \ \
         \ ROW KEY: request-id. "
    kda-account:string
    kda-guard:guard
    nonce:string
    request-id:string
    status:string
    expiration:time
    amount:decimal
  )
  (defschema sell-schema
    @doc " A request specifing the amount and accounts. \
         \ expiration is block-time + 24 hours \
         \ \
         \ ROW KEY: request-id. "
    token-address:string
    amount:decimal
    kda-account:string
    request-id:string
    status:string
    expiration:time
  )
  (deftable requests-buy:{buy-schema})
  (deftable requests-sell:{sell-schema})

  ; --------------------------------------------------------------------------
  ; Capabilities

  (defcap GOVERNANCE
    ()

    @doc " Give the admin full access to call and upgrade the module. "

    (enforce-keyset 'kbtc-admin)
  )

  (defcap OPERATIONS
    ()

    @doc " Operations keyset to perform key contract actions. "

    (enforce true "ops capability")
    ; (enforce-guard (at 'guard (read-keyset "kbtc-ops")))
  )

  (defcap DEBIT
    ( sender:string )

    @doc " Capability to perform debiting operations. "

    (enforce-guard (at 'guard (read token-table sender ['guard])))
    (enforce (!= sender "") "Invalid sender.")
  )

  (defcap CREDIT
    ( receiver:string )

    @doc " Capability to perform crediting operations. "

    (enforce (!= receiver "") "Invalid receiver.")
  )

  (defcap ROTATE
    ( account-id:string )

    @doc " Managed capability, scoping the execution of key rotation "
    @managed

    true
  )

  (defcap TRANSFER:bool
    ( sender:string
      receiver:string
      amount:decimal )

    @doc " Capability to perform transfer between two accounts. "

    @managed amount TRANSFER-mgr

    (enforce (!= sender receiver) "Sender cannot be the receiver.")
    (enforce-unit amount)
    (enforce (> amount 0.0) "Transfer amount must be positive.")
    (compose-capability (DEBIT sender))
    (compose-capability (CREDIT receiver))
  )

  (defun TRANSFER-mgr:decimal
    ( managed:decimal
      requested:decimal )

    (let ((newbal (- managed requested)))
      (enforce (>= newbal 0.0)
        (format "TRANSFER exceeded for balance {}" [managed]))
      newbal
    )
  )

  ; --------------------------------------------------------------------------
  ; Constants

  (defconst DECIMALS 12
    " Specifies the minimum denomination for token transactions. ")

  (defconst ACCOUNT_ID_CHARSET CHARSET_LATIN1
    " Allowed character set for account IDs. ")

  (defconst ACCOUNT_ID_PROHIBITED_CHARACTER "$")

  (defconst ACCOUNT_ID_MIN_LENGTH 3
    " Minimum character length for account IDs. ")

  (defconst ACCOUNT_ID_MAX_LENGTH 256
    " Maximum character length for account IDs. ")

  (defconst REQUEST_PENDING "pending"
    " Request to buy/sell token pending ")

  (defconst REQUEST_COMPLETE "complete"
    " Request to buy/sell token complete ")

  (defconst REQUEST_CANCELED "canceled"
    " Request to buy/sell token canceled by user ")

  (defconst REQUEST_REJECTED "rejected"
    " Request to buy/sell token canceled by OPERATIONS keyset ")

  (defconst EXPIRATION (days 1)
    " 24 hour time limit for requests to be open ")

  ; --------------------------------------------------------------------------
  ; Utilities

  (defun validate-account-id
    ( account-id:string )

    @doc " Enforce that an account ID meets charset and length requirements. "

    (enforce
      (is-charset ACCOUNT_ID_CHARSET account-id)
      (format
        "Account ID does not conform to the required charset: {}"
        [account-id]))

    (enforce
      (not (contains account-id ACCOUNT_ID_PROHIBITED_CHARACTER))
      (format "Account ID contained a prohibited character: {}" [account-id]))

    (let ((accountLength (length account-id)))

      (enforce
        (>= accountLength ACCOUNT_ID_MIN_LENGTH)
        (format
          "Account ID does not conform to the min length requirement: {}"
          [account-id]))

      (enforce
        (<= accountLength ACCOUNT_ID_MAX_LENGTH)
        (format
          "Account ID does not conform to the max length requirement: {}"
          [account-id]))
    )
  )

  ; --------------------------------------------------------------------------
  ; Operations Keyset Functions

  (defun get-buy-requests ()
    @doc " Get all the outstanding buy requests "
    (select requests-buy (where 'status (= REQUEST_PENDING)))
  )

  (defun get-sell-requests ()
    @doc " Get all the outstanding buy requests "
    (select requests-sell (where 'status (= REQUEST_PENDING)))
  )

  (defun complete-buy
    ( request-id:string
      amount:decimal )

    @doc " Allow OPERATIONS keyset to mint tokens and close request \
          \ to be called once token arrives to company account on native chain"

    (with-capability (OPERATIONS)
      (with-read requests-buy request-id
        { "kda-account" := account
        , "kda-guard"   := req-guard
        , "expiration"  := exp
        , "nonce"       := nonce
        , "status"      := status
        }
        (enforce (> (diff-time exp (at "block-time" (chain-data))) 0.0) "request has expired")
        (enforce (= status REQUEST_PENDING) "request is not pending")
        (update requests-buy request-id
          { "status" : REQUEST_COMPLETE
          , "amount" : amount
          }
        )
        ;creates user account if it does not exist
        (with-default-read token-table account
          { "balance"  : 0.0
          , "guard"    : req-guard
          }
          { "balance"  := balance
          , "guard"    := guard
          }
          ;make sure user isn't using a different guard for the same account
          (enforce (= req-guard guard) "cannot use a different guard for an existing account")
          (write token-table account
            { "balance"  : (+ balance amount)
            , "guard"    : guard
            }
          )
        )
        (inc-supply amount)
        (format "Buy request for {} with id: {} COMPLETED" [account, request-id])
      )
    )
  )

  (defun complete-sell
    ( request-id:string
      token-address:string )

    @doc " Allow OPERATIONS keyset to close request \
          \ to be called once company sends token to native chain \
          \ NOTE: tokens already burned by user when calling request-sell"

    (with-capability (OPERATIONS)
      (with-read requests-sell request-id
        { "kda-account" := account
        , "amount"      := amount
        , "expiration"  := exp
        , "status"      := status
        }
        (enforce (> (diff-time exp (at "block-time" (chain-data))) 0.0) "request has expired")
        (enforce (= status REQUEST_PENDING) "request is not pending")
        (update requests-sell request-id
          { "status"   : REQUEST_COMPLETE
          , "token-address" : token-address
          }
        )
        (format "Sell request for {} with id: {} COMPLETED" [account, request-id])
      )
    )
  )

  (defun reject-buy
    ( request-id:string )

    @doc " Allow OPERATIONS keyset to reject buy request "

    (with-capability (OPERATIONS)
      (with-read requests-buy request-id
        { "kda-account" := account
        , "amount"      := amount
        , "status"      := status
        }
        (enforce (= status REQUEST_PENDING) "request is not pending")
        (update requests-buy request-id
          { "status"   : REQUEST_REJECTED }
        )
        (format "Buy request for {} with id: {} REJECTED" [account, request-id])
      )
    )
  )

  (defun reject-sell
    ( request-id:string )

    @doc " Allow OPERATIONS keyset to reject sell request \
         \ NOTE: must return funds to user as they are burned in request-sell "

    (with-capability (OPERATIONS)
      (with-read requests-sell request-id
        { "kda-account" := account
        , "amount"      := amount
        , "status"      := status
        }
        (enforce (= status REQUEST_PENDING) "request is not pending")
        (update requests-sell request-id
          { "status"   : REQUEST_REJECTED }
        )
        (with-read token-table account
          { "balance" := balance }
          (update token-table account
            { "balance" : (+ balance amount) }
          )
          ;add token back to supply
          (inc-supply amount)
        )
        (format "Sell request for {} with id: {} REJECTED" [account, request-id])
      )
    )
  )


  ;; ; --------------------------------------------------------------------------
  ;; ; User Keyset Functions
  (defun make-request-id
    ( kda-account:string
      kda-guard:guard
      nonce:string )

    @doc "Construct the request ID used to look up a request"

    (hash { "account": kda-account, "guard": kda-guard, "nonce": nonce })
  )

  (defun buy-token
    ( kda-account:string
      kda-guard:guard
      nonce:string )

    @doc " Let ANYONE make a request to buy token to any account. \
          \ If specified account does not exist it will be created \
          \ Safe to leave open as no wrapped token will be issued \
          \   until token arrives on native chain "

    (let ((request-id (make-request-id kda-account kda-guard nonce)))
      (validate-account-id kda-account)
      (insert requests-buy request-id
        { "kda-account" : kda-account
        , "kda-guard"   : kda-guard
        , "nonce"       : nonce
        , "request-id"  : request-id
        , "status"      : REQUEST_PENDING
        , "expiration"  : (add-time (at "block-time" (chain-data)) EXPIRATION)
        , "amount"      : 0.0
        }
      )
      {"request-id": request-id}
    )
  )

  (defun sell-token
    ( token-address:string
      nonce:string
      kda-account:string
      amount:decimal )

    @doc " Let account holder make a sell request \
          \ Automatically burns the token \
          \ Waits for backend to send token to token-address then closes request "

    (validate-account-id kda-account)
    (enforce (> amount 0.0) "Debit amount must be positive.")
    (enforce-unit amount)

    (with-capability (DEBIT kda-account)
      (with-read token-table kda-account
        { "guard" := guard }

        (debit kda-account amount)
        (dec-supply amount)

        (let ((request-id (make-request-id kda-account guard nonce)))
          (insert requests-sell request-id
            { "token-address" : token-address
            , "amount"        : amount
            , "kda-account"   : kda-account
            , "request-id"    : request-id
            , "status"        : REQUEST_PENDING
            , "expiration"    : (add-time (at "block-time" (chain-data)) EXPIRATION)
            }
          )
          {"request-id": request-id}
        )
      )
    )
  )

  (defun cancel-buy
    ( request-id:string )

    @doc " Let account holder cancel a buy request \
          \ Verifies tx is signed with account in requests-buy table "

    (with-read requests-buy request-id
      { "kda-account" := account
      , "kda-guard"   := guard
      , "amount"      := amount
      , "status"      := status
      }
      (enforce-guard guard)
      (enforce (= status REQUEST_PENDING) "request is not pending")
      (update requests-buy request-id
        { "status" : REQUEST_CANCELED }
      )
      (format "Buy request for {} with id: {} CANCELED" [account, request-id])
    )
  )


  ;; ; --------------------------------------------------------------------------
  ;; ; Fungible-v2 Implementation

  (defun transfer-create:string
    ( sender:string
      receiver:string
      receiver-guard:guard
      amount:decimal )

    @doc " Transfer to an account, creating it if it does not exist. "

    (with-capability (TRANSFER sender receiver amount)
      (debit sender amount)
      (credit receiver receiver-guard amount)
    )
  )

  (defun transfer:string
    ( sender:string
      receiver:string
      amount:decimal )

    @doc " Transfer to an account, failing if the account does not exist. "


    (with-read token-table receiver
      { "guard" := guard }
      (transfer-create sender receiver guard amount)
    )
  )

  (defun debit
    ( account-id:string
      amount:decimal )

    @doc " Decrease an account balance. Internal use only. "


    (validate-account-id account-id)
    (enforce (> amount 0.0) "Debit amount must be positive.")
    (enforce-unit amount)
    (require-capability (DEBIT account-id))

    (with-read token-table account-id
      { "balance" := balance }

      (enforce (<= amount balance) "Insufficient funds.")

      (update token-table account-id
        { "balance" : (- balance amount) }
      )
    )
  )

  (defun credit
    ( account-id:string
      guard:guard
      amount:decimal )

    @doc " Increase an account balance. Internal use only. "


    (validate-account-id account-id)
    (enforce (> amount 0.0) "Credit amount must be positive.")
    (enforce-unit amount)
    (require-capability (CREDIT account-id))

    (with-default-read token-table account-id
      { "balance"  : 0.0
      , "guard"    : guard
      }
      { "balance"  := balance
      , "guard"    := currentGuard
      }
      (enforce (= currentGuard guard) "Account guards do not match.")

      (write token-table account-id
        { "balance"  : (+ balance amount)
        , "guard"    : currentGuard
        }
      )
    )
  )

  (defschema crosschain-schema
    @doc " Schema for yielded value in cross-chain transfers "
    receiver:string
    receiver-guard:guard
    amount:decimal
  )

  (defpact transfer-crosschain:string
    ( sender:string
      receiver:string
      receiver-guard:guard
      target-chain:string
      amount:decimal )

    (step
      (with-capability (DEBIT sender)

        (validate-account-id sender)
        (validate-account-id receiver)

        (enforce (!= "" target-chain) "empty target-chain")
        (enforce (!= (at 'chain-id (chain-data)) target-chain)
          "cannot run cross-chain transfers to the same chain")

        (enforce (> amount 0.0)
          "transfer quantity must be positive")

        (enforce-unit amount)

        ;; Step 1 - debit sender account on current chain
        (debit sender amount)

        (let
          ((
            crosschain-details:object{crosschain-schema}
            { "receiver"       : receiver
            , "receiver-guard" : receiver-guard
            , "amount"         : amount
            }
          ))
          (yield crosschain-details target-chain)
        )
      )
    )

    (step
      (resume
        { "receiver"       := receiver
        , "receiver-guard" := receiver-guard
        , "amount"         := amount
        }
        ;; Step 2 - credit receiver account on target chain
        (with-capability (CREDIT receiver)
          (credit receiver receiver-guard amount)
        )
      )
    )
  )

  (defun get-balance:decimal (account:string)
    (with-read token-table account
      { "balance" := balance }
      balance
      )
    )

  (defun details:object{fungible-v2.account-details}
  ;(defun details
    ( account:string )

    (with-read token-table account
      { "balance" := balance
      , "guard"   := guard
      }
      { "account" : account
      , "balance" : balance
      , "guard"   : guard
      }
    )
  )

  (defun init-stats ()

    @doc " Initialize token stats with supply as 0 "

    (insert stats "total"
      { "supply" : 0.0 }
    )
  )

  (defun inc-supply
    ( amount:decimal )

    @doc " Increase token supply. Internal use only. "

    (with-read stats "total"
      { "supply" := supply }
      (update stats "total"
      { "supply" : (+ supply amount)}
      )
    )
  )

  (defun dec-supply
    ( amount:decimal )

    @doc " Decrease token supply. Internal use only. "

    (with-read stats "total"
      { "supply" := supply }
      (update stats "total"
      { "supply" : (- supply amount)}
      )
    )
  )

  (defun get-supply ()

    @doc " Getter for total cirulating token supply "

    (with-read stats "total"
      { "supply" := supply }
      { "supply" : supply }
    )
  )

  (defun precision:integer
    ()

    DECIMALS
  )

  (defun enforce-unit:bool
    ( amount:decimal )

    @doc " Enforce the minimum denomination for token transactions. "

    (enforce
      (= (floor amount DECIMALS) amount)
      (format "Amount violates minimum denomination: {}" [amount])
    )
  )

  (defun create-account:string
    ( account:string
      guard:guard )

    @doc " Create a new account. "


    (insert token-table account
      { "balance" : 0.0
      , "guard"   : guard
      }
    )
  )

  (defun rotate:string
    ( account:string
      new-guard:guard )

    @doc " Rotate guard for a given account "

    (with-capability (ROTATE account)

      (with-read token-table account
        { "guard" := oldGuard }

        (enforce-guard oldGuard)
        (enforce-guard new-guard)

        (update token-table account
          { "guard" : new-guard }
        )
      )
    )
  )

)

(create-table token-table)
(create-table requests-buy)
(create-table requests-sell)
(create-table stats)
(init-stats)

;; for local blockchain testing
;; (buy-token "test" (read-keyset "ks") "some-nonce")
;; (complete-buy (hash { "account": "test", "guard": (read-keyset "ks"), "nonce": "some-nonce" }) 20.0)
