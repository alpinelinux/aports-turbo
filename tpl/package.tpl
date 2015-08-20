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
                                    <div class="table-responsive">
                                        <table class="table table-striped table-bordered table-condensed">
                                            {{#pkg}}
                                            <tr>
                                                <th>{{{head}}}</th>
                                                {{#url}}
                                                <td><a href="{{{path}}}">{{{text}}}</a></td>
                                                {{/url}}
                                                {{^url}}
                                                <td>{{{data}}}</td>
                                                {{/url}}
                                            </tr>
                                            {{/pkg}}
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
