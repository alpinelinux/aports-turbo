{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Package details</div>
            <div class="panel-body">
                <div class="container-fluid">
                    <div class="row">
                        <div class="col-md-8">
                            <div class="panel panel-default">
                                <div class="panel-heading">General</div>
                                <div class="panel-body">
                                    <table class="table table-striped table-bordered table-condensed">{{#name}}
                                        <tr>
                                            <th>Name:</th>
                                            <td title="{{{desc}}}"><a href="/package/{{{name}}}">{{{name}}}</a></td>
                                        </tr>
                                        <tr>
                                            <th>Version:</th>
                                            <td>{{{version}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Description:</th>
                                            <td>{{{desc}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Project:</th>
                                            <td><a href="{{{url}}}">URL</a></td>
                                        </tr>
                                        <tr>
                                            <th>Licence:</th>
                                            <td>{{{lic}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Architecture:</th>
                                            <td>{{{arch}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Checksum:</th>
                                            <td>{{{csum}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Size:</th>
                                            <td>{{{size}}} Bytes</td>
                                        </tr>{{#install_size}}
                                        <tr>
                                            <th>Installed size:</th>
                                            <td>{{{install_size}}} Bytes</td>
                                        </tr>{{/install_size}}{{#provides}}
                                        <tr>
                                            <th>Provides:</th>
                                            <td>{{{provides}}}</td>
                                        </tr>{{/provides}}{{#install_if}}
                                        <tr>
                                            <th>Install if:</th>
                                            <td>{{{install_if}}}</td>
                                        </tr>{{/install_if}}{{#name}}
                                        <tr>
                                            <th>Origin:</th>
                                            <td><a href="/package/{{{arch}}}/{{{origin}}}">{{{origin}}}</a></td>
                                        </tr>
                                        <tr>
                                            <th>Maintainer:</th>
                                            <td>{{{maintainer}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Build time:</th>
                                            <td>{{{build_time}}}</td>
                                        </tr>
                                        <tr>
                                            <th>Commit:</th>
                                            <td><a href="http://git.alpinelinux.org/cgit/aports/commit/?id={{{commit}}}">{{{commit}}}</a></td>
                                        </tr>
                                        <tr>
                                            <th>Contents:</th>
                                            <td><a href="/contents?pkgname={{{name}}}&amp;arch={{{arch}}}">Contents of package</a></td>
                                        </tr>{{/name}}{{^name}}
                                        <tr>
                                            <td>This package does not exist!</td>
                                        </tr>{{/name}}
                                    </table>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-md-offset-1">
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseDeps" aria-expanded="false">Dependecies ({{deps_qty}})</a>
                                </div>
                                <div id="collapseDeps" class="panel-collapse collapse">
                                    <ul class="list-group">{{#deps}}
                                        <li class="list-group-item"><a href="/package/{{{arch}}}/{{{dep}}}">{{{dep}}}</a></li>{{/deps}}{{^deps}}<li class="list-group-item">None</li>{{/deps}}
                                    </ul>
                                </div>
                            </div>
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseReqBy" aria-expanded="false">Required by ({{reqdeps_qty}})</a>
                                </div>
                                <div id="collapseReqBy" class="panel-collapse collapse">
                                    <ul class="list-group">{{#reqbys}}
                                        <li class="list-group-item"><a href="/package/{{{arch}}}/{{{reqby}}}">{{{reqby}}}</a></li>{{/reqbys}}{{^reqbys}}<li class="list-group-item">None</li>{{/reqbys}}
                                    </ul>
                                </div>
                            </div>
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseSubPkg" aria-expanded="false">Sub Packages ({{subpkgs_qty}})</a>
                                </div>
                                <div id="collapseSubPkg" class="panel-collapse collapse">
                                    <ul class="list-group">{{#subpkgs}}
                                        <li class="list-group-item"><a href="/package/{{{arch}}}/{{{subpkg}}}">{{{subpkg}}}</a></li>{{/subpkgs}}{{^subpkgs}}<li class="list-group-item">None</li>{{/subpkgs}}
                                    </ul>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
{{{footer}}}
