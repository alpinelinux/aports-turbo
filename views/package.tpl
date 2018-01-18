{{{header}}}
    <main id="package">
        <div class="grid-head">Package details</div>
        <div class="grid-body">
            <div class="pure-g">
                <div class="pure-u-1 pure-u-lg-15-24">
                    <div class="table-responsive">
                        <table class="pure-table pure-table-striped" id="package">
                            <tr>
                                <th class="header">Package</th>
                                <td>{{pkg.name}}</td>
                            </tr>
                            <tr>
                                <th class="header">Version</th>
                                <td>
                                    {{#pkg.flaggable}}
                                    <strong>
                                        <a class="hint--right {{pkg.version.class}}" aria-label="{{pkg.version.title}}" href="{{pkg.version.path}}">{{pkg.version.text}}</a>
                                    </strong>
                                    {{/pkg.flaggable}}
                                    {{^pkg.flaggable}}
                                        {{pkg.version.text}}
                                    {{/pkg.flaggable}}
                                </td>
                            </tr>
                            <tr>
                                <th class="header">Description</th>
                                <td>{{pkg.description}}</td>
                            </tr>
                            <tr>
                                <th class="header">Project</th>
                                <td><a href="{{pkg.url}}">{{pkg.url}}</a></td>
                            </tr>
                            <tr>
                                <th class="header">License</th>
                                <td>{{pkg.license}}</td>
                            </tr>
                            <tr>
                                <th class="header">Branch</th>
                                <td>{{pkg.branch}}</td>
                            </tr>
                            <tr>
                                <th class="header">Repository</th>
                                <td>{{pkg.repo}}</td>
                            </tr>
                            <tr>
                                <th class="header">Architecture</th>
                                <td>{{pkg.arch}}</td>
                            </tr>
                            <tr>
                                <th class="header">Size</th>
                                <td>{{pkg.size}}</td>
                            </tr>
                            <tr>
                                <th class="header">Installed size</th>
                                <td>{{pkg.installed_size}}</td>
                            </tr>
                            <tr>
                                <th class="header">Origin</th>
                                <td><a href="{{pkg.origin.path}}">{{pkg.origin.text}}</a></td>
                            </tr>
                            <tr>
                                <th class="header">Maintainer</th>
                                <td>{{pkg.maintainer}}</td>
                            </tr>
                            <tr>
                                <th class="header">Build time</th>
                                <td>{{pkg.build_time}}</td>
                            </tr>
                            <tr>
                                <th class="header">Commit</th>
                                <td><a href="{{pkg.commit.path}}">{{pkg.commit.text}}</a></td>
                            </tr>
                            <tr>
                                <th class="header">Git repository</th>
                                <td><a href="{{pkg.git}}">Git repository</a></td>
                            </tr>
                            <tr>
                                <th class="header">Build log</th>
                                <td><a href="{{pkg.log}}">Build log</a></td>
                            </tr>
                            <tr>
                                <th class="header">Contents</th>
                                <td><a href="{{pkg.contents.path}}">{{pkg.contents.text}}</a></td>
                            </tr>
                        </table>
                    </div>
                    <div class="flag-button">
                        <a class="pure-button" href="{{pkg.version.path}}">Flag</a>
                    </div>
                </div>
                <div class="pure-u-1 pure-u-lg-3-24"></div>
                <div class="pure-u-1 pure-u-lg-6-24 multi-fields">
                    <details>
                        <summary>Depends ({{deps_qty}})</summary>
                        <div class="pure-menu custom-restricted-width">
                            <ul class="pure-menu-list">
                                {{#deps}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">{{text}}</a></li>{{/deps}}
                                {{^deps}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">None</a></li>{{/deps}}
                            </ul>
                        </div>
                    </details>
                    <details>
                        <summary>Required by ({{reqbys_qty}})</summary>
                        <div class="pure-menu custom-restricted-width">
                            <ul class="pure-menu-list">
                                {{#reqbys}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">{{text}}</a></li>{{/reqbys}}
                                {{^reqbys}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">None</a></li>{{/reqbys}}
                            </ul>
                        </div>
                    </details>
                    <details>
                        <summary>Sub Packages ({{subpkgs_qty}})</summary>
                        <div class="pure-menu custom-restricted-width">
                            <ul class="pure-menu-list">
                                {{#subpkgs}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">{{text}}</a></li>{{/subpkgs}}
                                {{^subpkgs}}<li class="pure-menu-item"><a class="pure-menu-link" href="{{path}}">None</a></li>{{/subpkgs}}
                            </ul>
                        </div>
                    </details>
                </div>
            </div>
        </div>
    </main>
{{{footer}}}
