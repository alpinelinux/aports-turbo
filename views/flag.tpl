{{{header}}}
    <main id="flag">
        <div class="grid-head">Flag package</div>
        <div class="grid-body">
            <div class="pure-g">
                <div class="pure-u-1 pure-u-lg-12-24">
                    <div class="grid-head">Your information</div>
                    <div class="grid-body">
                        <form class="pure-form pure-form-stacked" method="POST">
                            <div class="input-group {{form.from.class}}">
                                <label for="email">Email</label>
                                <input type="email" class="pure-input-1" name="from" value="{{form.value.from}}" placeholder="Enter email">
                                <span class="pure-form-message">Your email address the developer can contact you on.</span>
                            </div>
                            <div class="input-group {{form.version.class}}">
                                <label class="control-label">New version</label>
                                <input type="text" class="pure-input-1" name="new_version" value="{{form.value.new_version}}" placeholder="Enter version">
                                <span class="pure-form-message">The new version number from upstream.</span>
                            </div>
                            <div class="input-group {{form.message.class}}">
                                <label for="comment">Message</label>
                                <textarea rows="5" class="pure-input-1" maxlength="250" name="message" placeholder="Your message goes here...">{{form.value.message}}</textarea>
                                <span class="pure-form-message">Leave a message to the developer.</span>
                            </div>
                            {{#sitekey}}
                            <!-- sorry ppl but javascript is the only way... -->
                            <script src="https://www.google.com/recaptcha/api.js" async defer></script>
                            <div class="g-recaptcha" data-sitekey="{{sitekey}}"></div>
                            {{/sitekey}}
                            <button type="submit" class="pure-button pure-button-primary">Flag it!</button>

                        </form>
                    </div>
                </div>
                <div class="pure-u-1 pure-u-lg-2-24"></div>
                <div class="pure-u-1 pure-u-lg-10-24">
                    <div class="grid-head">Package information</div>
                    <div class="grid-body">
                        <table class="pure-table pure-table-striped" id="package">
                            <tbody>
                                <tr><th class="header">Origin name</th><td>{{origin}}</td></tr>
                                <tr><th class="header">Repository</th><td>{{repo}}</td></tr>
                                <tr><th class="header">Version</th><td>{{version}}</td></tr>
                            </tbody>
                        </table>
                        <aside>Flagging a package out of date will always select the origin package.
                        This means if you have selected another package to flag this is most probably a subpackage of ({{origin}})</aside>
                        <aside style="background-color: #feecf0; color: cc0f35;">
                          This form is intented to report outdated packages.
                          Please report all other issues related to {{origin}} via the <a href="https://gitlab.alpinelinux.org/alpine/aports/-/issues">bug tracker</a>
                        </aside>
                    </div>
                </div>
            </div>
        </div>
    </main>
{{{footer}}}

