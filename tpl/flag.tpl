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
                                        <div class="form-group">
                                            <label class="control-label" for="exampleInputEmail1">Email</label>
                                            <input type="from" name="from" class="form-control" id="exampleInputEmail1" placeholder="Enter email">
                                            <p class="help-block">Your email address the developer can contact you on.</p>
                                        </div>
                                        
                                        <div class="form-group">
                                            <label for="comment">Message</label>
                                            <textarea class="form-control" rows="5" name="message"></textarea>
                                            <p class="help-block">Leave a message to the developer.</p>{{{#sitekey}}}
                                            <script src="https://www.google.com/recaptcha/api.js" async defer></script>
                                            <div class="g-recaptcha" data-sitekey="{{{sitekey}}}"></div>{{{/sitekey}}}
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
                                            <tr><th>Origin name</th><td>{{{origin}}}</td></tr>
                                            <tr><th>Repository</th><td>{{{repo}}}</td></tr>
                                            <tr><th>Version</th><td>{{{version}}}</td></tr>
                                            <tr><th>Maintainer</th><td>{{{maintainer}}}</td></tr>
                                        </tbody>
                                    </table>
                                    <div class="alert alert-warning" role="alert">Flagging a package out of date, will always select the orgin package. This means if you have selected another package to flag this is most probably a subpackage of ({{{origin}}})</div>
                                 </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{{{footer}}}

