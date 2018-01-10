{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Flag a package out of date</div>
            <div class="panel-body">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="panel panel-default">
                                <div class="panel-heading">Your information</div>
                                <div class="panel-body">
                                    <form role="form" method="POST">
                                        <div class="form-group {{{form.status.from}}}">
                                            <label class="control-label">Email</label>
                                            <input type="email" name="from" class="form-control" value="{{form.value.from}}" placeholder="Enter email">
                                            <p class="help-block">Your email address the developer can contact you on.</p>
                                        </div>
                                        <div class="form-group {{{form.status.new_version}}}">
                                            <label class="control-label">New version</label>
                                            <input type="text" name="new_version" class="form-control" value="{{form.value.new_version}}" placeholder="Enter version">
                                            <p class="help-block">The new version number from upstream.</p>
                                        </div>
                                        <div class="form-group {{{form.status.message}}}">
                                            <label for="comment">Message</label>
                                            <textarea class="form-control" rows="5" name="message">{{form.value.message}}</textarea>
                                            <p class="help-block">Leave a message to the developer.</p>{{#sitekey}}
                                            <script src="https://www.google.com/recaptcha/api.js" async defer></script>
                                            <div class="g-recaptcha" data-sitekey="{{sitekey}}"></div>{{/sitekey}}
                                        </div>
                                        <button type="submit" class="btn btn-primary">Flag it!</button>
                                    </form>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-5 col-md-offset-1">
                            <div class="panel panel-default">
                                 <div class="panel-heading">Package</div>
                                 <div class="panel-body">
                                    <table class="table table-striped table-bordered table-condensed">
                                        <tbody>
                                            <tr><th>Origin name</th><td>{{origin}}</td></tr>
                                            <tr><th>Repository</th><td>{{repo}}</td></tr>
                                            <tr><th>Version</th><td>{{version}}</td></tr>
                                        </tbody>
                                    </table>
                                    <div class="alert alert-warning" role="alert">Flagging a package out of date will always select the orgin package. This means if you have selected another package to flag this is most probably a subpackage of ({{origin}})</div>
                                 </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{{{footer}}}

