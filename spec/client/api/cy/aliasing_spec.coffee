describe "$Cypress.Cy Aliasing Commands", ->
  enterCommandTestingMode()

  context "#assign", ->
    beforeEach ->
      @cy.noop("foo").assign("foo")

    afterEach ->
      if not @foo
        @test.error new Error("this.foo not defined")

      if not @noop
        @test.error new Error("this.noop not defined")

    it "assigns subject to runnable ctx", ->
      @cy
        .noop({}).assign("noop").then (obj) ->
          expect(@noop).to.eq obj

    describe "nested hooks", ->
      afterEach ->
        if not @bar
          @test.error new Error("this.bar not defined")

        if not @foo
          @test.error new Error("this.foo not defined")

        if not @noop
          @test.error new Error("this.noop not defined")

      it "assigns bar", ->
        @cy.noop("bar").assign("bar")

    describe "nested functions", ->
      beforeEach ->
        @assign = =>
          @cy.noop("baz").assign("baz")

      afterEach ->
        if not @baz
          @test.error new Error("this.baz not defined")

      it "shares this ctx with hooks", ->
        @assign().then ->
          expect(@baz).to.eq("baz")

  context "#as", ->
    it "does not change the subject", ->
      body = @cy.$("body")

      @cy.get("body").as("b").then ($body) ->
        expect($body.get(0)).to.eq body.get(0)

    it "stores the lookup as an alias", ->
      @cy.get("body").as("b").then ->
        expect(@cy._aliases.b).to.be.defined

    it "stores the resulting subject as the alias", (done) ->
      body = @cy.$("body")

      @cy.on "end", ->
        expect(@_aliases.b.subject.get(0)).to.eq body.get(0)
        done()

      @cy.get("body").as("b")

    it "stores subject of chained aliases", ->
      li = @cy.$("#list li").eq(0)

      @cy.get("#list li").eq(0).as("firstLi").then ($li) ->
        expect($li).to.match li

  context "#_replayFrom", ->
    describe "subject in document", ->
      it "returns if subject is still in the document", (done) ->
        @cy.on "end", ->
          expect(@queue.length).to.eq 3
          done()

        @cy
          .get("#list").as("list")
          .get("@list")

    describe "subject not in document", ->
      it "inserts into the queue", (done) ->
        @cy.on "end", ->
          expect(getNames(@queue)).to.deep.eq(
            ["get", "eq", "as", "then", "get", "get", "eq"]
          )
          done()

        @cy
          .get("#list li").eq(0).as("firstLi").then ($li) ->
            $li.remove()
          .get("@firstLi")

      it "replays from last root to current", ->
        first = @cy.$("#list li").eq(0)
        second = @cy.$("#list li").eq(1)

        @cy
          .get("#list li").eq(0).as("firstLi").then ($li) ->
            expect($li.get(0)).to.eq first.get(0)
            $li.remove()
          .get("@firstLi").then ($li) ->
            expect($li.get(0)).to.eq second.get(0)

      it "replays up until first root command", (done) ->
        @cy.on "end", ->
          expect(getNames(@queue)).to.deep.eq(
            ["get", "noop", "get", "eq", "as", "then", "get", "get", "eq"]
          )
          done()

        @cy
          .get("body").noop({})
          .get("#list li").eq(0).as("firstLi").then ($li) ->
            $li.remove()
          .get("@firstLi")

      it "resets the chainerId allow subjects to be carried on", ->
        @cy
          .get("#dom").find("#button").as("button").then ($button) ->
            $button.remove()

            @cy.$("#dom").append $("<button />", id: "button")

            null

        ## when @cy is a separate chainer there *was* a bug
        ## that cause the subject to null because of different
        ## chainer id's
        @cy.get("@button").then ($button) ->
          expect($button).to.have.id("button")

  context "#getAlias", ->
    it "retrieves aliases", ->
      @cy.on "end", ->
        expect(@getAlias("@firstInput")).to.be.defined

      @cy
        .get("body").as("b")
        .get("input:first").as("firstInput")
        .get("div:last").as("lastDiv")

    describe "errors", ->
      beforeEach ->
        @allowErrors()

      it "throws when an alias cannot be found", (done) ->
        @cy.on "fail", (err) ->
          expect(err.message).to.include "cy.get() could not find a registered alias for: 'lastDiv'.  Available aliases are: 'b, firstInput'."
          done()

        @cy
          .get("body").as("b")
          .get("input:first").as("firstInput")
          .get("@lastDiv")

      it "throws when alias is missing '@' but matches an available alias", (done) ->
        @cy.on "fail", (err) ->
          expect(err.message).to.eq "Invalid alias: 'getAny'. You forgot the '@'. It should be written as: '@getAny'."
          done()

        @cy
          .server()
          .route("*", {}).as("getAny")
          .wait("getAny").then ->
