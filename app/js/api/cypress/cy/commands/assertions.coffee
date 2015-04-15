$Cypress.register "Assertions", (Cypress, _, $) ->

  bRe          = /(\[b\])(.+)(\[\\b\])/
  bTagOpen     = /\[b\]/g
  bTagClosed   = /\[\\b\]/g
  allButs      = /\bbut\b/g

  convertTags = ($row) ->
    html = $row.html()

    ## bail if matches werent found
    return if not bRe.test(html)

    html = html
      .replace(bTagOpen, ": <strong>")
      .replace(bTagClosed, "</strong>")
      .split(" :").join(":")

    $row.html(html)

  ## Rules:
  ## 1. always remove value
  ## 2. if value is a jquery object set a subject
  ## 3. if actual is undefined or its not expected remove both actual + expected
  parseValueActualAndExpected = (value, actual, expected) ->
    obj = {actual: actual, expected: expected}

    if value instanceof $
      obj.subject = value

      if _.isUndefined(actual) or actual isnt expected
        delete obj.actual
        delete obj.expected

    obj

  Cypress.addChildCommand
    to: (subject, chainers, args...) ->
      exp = $Cypress.Chai.expect(subject).to

      chainers = chainers.split(".")
      lastChainer = _(chainers).last()

      ## backup the original assertion subject
      originalObj = exp._obj

      _.reduce chainers, (memo, value) =>
        if value not of memo
          @throwErr("The chainer: '#{value}' was not found. Building implicit expectation failed.")

        if value is lastChainer
          if _.isFunction(memo[value])
            memo[value].apply(memo, args)
        else
          memo[value]
      , exp

      ## if the _obj has been mutated then we
      ## are chaining assertion properties and
      ## should return this new subject
      if originalObj isnt exp._obj
        return exp._obj

      return subject

    should: (subject, args...) ->
      @sync.to.apply(@, args)

  $Cypress.Cy.extend
    assert: (passed, message, value, actual, expected, error) ->
      ## if this is a jquery object and its true
      ## then remove all the 'but's and replace with 'and'
      ## also just think about slicing off everything after a comma?
      message = message.split(allButs).join("and") if message and passed

      obj = parseValueActualAndExpected(value, actual, expected)

      if $Cypress.Utils.hasElement(value)
        obj.$el = value

      functionHadArguments = (fn) ->
        fn and _.isFunction(fn) and fn.length > 0

      _.extend obj,
        name:     "assert"
        end:      true
        snapshot: true
        message:  message
        passed:   passed
        selector: value?.selector
        error:    error
        type: (current, subject) ->
          ## if our current command has arguments assume
          ## we are an assertion that's involving the current
          ## subject or our value is the current subject
          if value is subject or functionHadArguments(current.args[0])
            "child"
          else
            "parent"

        onRender: ($row) =>
          klass = if passed then "passed" else "failed"
          $row.addClass "command-assertion-#{klass}"

          ## converts [b] string tags into real elements
          convertTags($row)
        onConsole: =>
          obj = {Command: "assert"}

          _.extend obj, parseValueActualAndExpected(value, actual, expected)

          _.extend obj,
            Message: message.replace(bTagOpen, "").replace(bTagClosed, "")

      ## think about completely gutting the whole object toString
      ## which chai does by default, its so ugly and worthless

      if error
        error.onFail = (err) ->

      Cypress.command obj

      return Cypress