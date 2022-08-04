{{{header}}}
        <main id="packages">
            <div class="grid-head">Package filter</div>
            <div class="grid-body" id="search-form">
                <div class="pure-g">
                    <div class="pure-u-1">
                        <form class="pure-form pure-form-stacked">
                            <div class="pure-g">
                                <div class="pure-u-1 pure-u-md-4-24 form-field hint--top" aria-label="Use * and ? as wildcards">
                                        <input class="pure-input-1" type="text" id="name" name="name" value="{{form.name}}" placeholder="Package name" autofocus>
                                </div>
                                <div class="pure-u-1 pure-u-md-2-24 form-field">
                                    <select class="pure-input-1" name="branch" id="branch">
                                        <option value="" disabled {{form.placeholder.branch}}>Branch</option>
                                    {{#form.branch}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.branch}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-2-24 form-field">
                                    <select class="pure-input-1" name="repo" id="repo">
                                        <option value="" {{form.placeholder.repo}}>Repository</option>
                                    {{#form.repo}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.repo}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-2-24 form-field">
                                    <select class="pure-input-1" name="arch" id="arch">
                                        <option value="" {{form.placeholder.arch}}>Arch</option>
                                    {{#form.arch}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.arch}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-5-24 form-field">
                                    <select class="pure-input-1" name="maintainer" id="maintainer">
                                        <option value="" {{form.placeholder.maintainer}}>Maintainer</option>
                                    {{#form.maintainer}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.maintainer}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-3-24 form-button">
                                    <button type="submit" class="pure-button pure-button-primary">Search</button>
                                </div>
                            </div>
                        </form>
                    </div>
                </div>
            </div>
            <div class="table-responsive">
                <table class="pure-table pure-table-striped">
                    <thead>
                        <tr>
                            <th>Package</th>
                            <th>Version</th>
                            <th>Project</th>
                            <th>Licence</th>
                            <th>Branch</th>
                            <th>Repository</th>
                            <th>Architecture</th>
                            <th>Maintainer</th>
                            <th>Build date</th>
                        </tr>
                    </thead>
                    <tbody>
                    {{#pkgs}}
                    <tr>
                        <td class="package">
                            <a class="hint--right" aria-label="{{name.title}}" href="{{name.path}}">{{name.text}}</a>
                        </td>
                        {{#default}}
                        <td class="version">
                            <strong>
                                <a class="hint--right {{version.class}}" aria-label="{{version.title}}" href="{{version.path}}">{{version.text}}</a>
                            </strong>
                        </td>
                        {{/default}}
                        {{^default}}
                        <td class="version">{{version.text}}</td>
                        {{/default}}
                        <td class="url"><a href="{{url.path}}">{{url.text}}</a></td>
                        <td class="license">{{license}}</td>
                        <td class="branch">{{branch}}</td>
                        <td class="repo">
                            <a class="hint--right" aria-label="{{repo.title}}" href="?name={{args.name}}&branch={{args.branch}}&repo={{repo.text}}&arch={{args.arch}}&maintainer={{args.maintainer}}">
                                {{repo.text}}
                            </a>
                        </td>
                        <td class="arch">
                            <a class="hint--right" aria-label="{{arch.title}}" href="?name={{args.name}}&branch={{args.branch}}&repo={{args.repo}}&arch={{arch.text}}&maintainer={{args.maintainer}}">
                                {{arch.text}}
                            </a>
                        </td>
                        <td class="maintainer">
                            <a class="hint--right" aria-label="{{maintainer.title}}" href="?name={{args.name}}&branch={{args.branch}}&repo={{args.repo}}&arch={{args.arch}}&maintainer={{maintainer.text}}">
                                {{maintainer.text}}
                            </a>
                        </td>
                        <td class="bdate">{{build_time}}</td>
                    </tr>
                    {{/pkgs}}
                    {{^pkgs}}
                    <tr>
                        <td colspan="9">No item found...</td>
                    </tr>
                    {{/pkgs}}
                    </tbody>
                </table>
            </div>
            <div class="pure-menu pure-menu-horizontal" id="pagination">
                <nav>
                    <ul class="pure-menu-list">
                    {{#pager}}
                    <li class="pure-menu-item {{{class}}}"><a class="pure-menu-link" href="/packages?{{{args}}}">{{{page}}}</a></li>
                    {{/pager}}
                    </ul>
                </nav>
            </div>
        </main>
{{{footer}}}
