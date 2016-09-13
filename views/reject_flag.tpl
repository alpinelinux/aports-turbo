{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Flag a package out of date</div>
            <div class="panel-body">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-md-6">
                            <div class="panel panel-danger">
                                <div class="panel-heading">Important please read!</div>
                                <div class="panel-body">
                                	<p>You can only flag packages in our edge repository. Flagging stable packages is not allowd. The only valid reasons to upgrade a package is</p>
                                	<ol>
                                		<li>A security issue <abbr title="Common Vulnerabilities and Exposures">CVE</abbr> has been found.</li>
                            			<li>A severe bug/issue has been found in the package and a patch has been released to resolve it.</li>
                        			</ol>
                        			<p>If you want to report a <abbr title="Common Vulnerabilities and Exposures">CVE</abbr> or severe issue, please open an issue on our <a href="https://bugs.alpinelinux.org">bug tracker</a></p>
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
                                            <tr><th>Maintainer</th><td>{{maintainer}}</td></tr>
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

