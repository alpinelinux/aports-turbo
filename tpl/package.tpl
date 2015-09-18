{{{header}}}
    <script>$(document).ready(function(){$('[data-toggle="tooltip"]').tooltip({container: 'html'});});</script>
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
                                    <div class="table-responsive">
                                        <table class="table table-striped table-bordered table-condensed">
                                            <tr>
                                                <th>Package</th>
                                                <td>{{{pkg.name}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Version</th>
                                                <td>
                                                    <strong>
                                                        <a data-toggle="tooltip" title="{{{pkg.version.title}}}" class="{{{pkg.version.class}}}" href="{{{pkg.version.path}}}">{{{pkg.version.text}}}</a>
                                                    <strong>
                                                </td>
                                            </tr>
                                            <tr>
                                                <th>Description</th>
                                                <td>{{{pkg.description}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Project</th>
                                                <td><a href="{{{pkg.url}}}">{{{pkg.url}}}</a></td>
                                            </tr>
                                            <tr>
                                                <th>License</th>
                                                <td>{{{pkg.license}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Repository</th>
                                                <td>{{{pkg.repo}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Architecture</th>
                                                <td>{{{pkg.arch}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Size</th>
                                                <td>{{{pkg.size}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Installed size</th>
                                                <td>{{{pkg.installed_size}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Origin</th>
                                                <td><a href="{{{pkg.origin.path}}}">{{{pkg.origin.text}}}</a></td>
                                            </tr>
                                            <tr>
                                                <th>Maintainer</th>
                                                <td>{{{pkg.maintainer}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Build time</th>
                                                <td>{{{pkg.build_time}}}</td>
                                            </tr>
                                            <tr>
                                                <th>Commit</th>
                                                <td><a href="{{{pkg.commit.path}}}">{{{pkg.commit.text}}}</a></td>
                                            </tr>
                                            <tr>
                                                <th>Build log</th>
                                                <td><a href="http://build.alpinelinux.org/buildlogs/build-edge-{{{pkg.arch}}}/{{{pkg.repo}}}/{{{pkg.origin.text}}}/{{{pkg.origin.text}}}-{{{pkg.version.text}}}.log">Build log</a></td>
                                            </tr>
                                            <tr>
                                                <th>Contents</th>
                                                <td><a href="{{{pkg.contents.path}}}">{{{pkg.contents.text}}}</a></td>
                                            </tr>
                                        </table>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-md-offset-1">
                            <!-- Dependencies -->
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseDeps" aria-expanded="false">Dependecies ({{deps_qty}})</a>
                                </div>
                                <div id="collapseDeps" class="panel-collapse collapse">
                                    <ul class="list-group">
                                    {{#deps}}<li class="list-group-item"><a href="{{{path}}}">{{{text}}}</a></li>{{/deps}}
                                    {{^deps}}<li class="list-group-item">None</li>{{/deps}}
                                    </ul>
                                </div>
                            </div>
                            <!-- Required by -->
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseReqBy" aria-expanded="false">Required by ({{reqbys_qty}})</a>
                                </div>
                                <div id="collapseReqBy" class="panel-collapse collapse">
                                    <ul class="list-group">
                                    {{#reqbys}}<li class="list-group-item"><a href="{{{path}}}">{{{text}}}</a></li>{{/reqbys}}
                                    {{^reqbys}}<li class="list-group-item">None</li>{{/reqbys}}
                                    </ul>
                                </div>
                            </div>
                            <!-- Subpackages -->
                            <div class="panel panel-default">
                                <div class="panel-heading">
                                    <a class="accordion-toggle" data-toggle="collapse" href="#collapseSubPkg" aria-expanded="false">Sub Packages ({{subpkgs_qty}})</a>
                                </div>
                                <div id="collapseSubPkg" class="panel-collapse collapse">
                                    <ul class="list-group">
                                    {{#subpkgs}}<li class="list-group-item"><a href="{{{path}}}">{{{text}}}</a></li>{{/subpkgs}}
                                    {{^subpkgs}}<li class="list-group-item">None</li>{{/subpkgs}}
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
