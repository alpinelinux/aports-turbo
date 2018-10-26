{{{header}}}
        <main id="contents">
            <div class="grid-head">Contents filter</div>
            <div class="grid-body" id="search-form">
                <div class="pure-g">
                    <div class="pure-u-1">
                        <form class="pure-form pure-form-stacked">
                            <div class="pure-g">
                                <div class="pure-u-1 pure-u-md-4-24 form-field hint--top" aria-label="Use * and ? as wildcards">
                                        <input class="pure-input-1" type="text" id="file" name="file" value="{{form.file}}" placeholder="File" autofocus>
                                </div>
                                <div class="pure-u-1 pure-u-md-4-24 form-field hint--top" aria-label="Use * and ? as wildcards">
                                        <input class="pure-input-1" type="text" id="path" name="path" value="{{form.path}}" placeholder="Path">
                                </div>
                                <div class="pure-u-1 pure-u-md-4-24 form-field hint--top" aria-label="Use * and ? as wildcards">
                                        <input class="pure-input-1" type="text" id="name" name="name" value="{{form.name}}" placeholder="Package">
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
                                        <option value="" disabled {{form.placeholder.repo}}>Repository</option>
                                    {{#form.repo}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.repo}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-2-24 form-field">
                                    <select class="pure-input-1" name="arch" id="arch">
                                        <option value="" disabled {{form.placeholder.arch}}>Arch</option>
                                    {{#form.arch}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.arch}}
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
                            <th>File</th>
                            <th>Package</th>
                            <th>Branch</th>
                            <th>Repository</th>
                            <th>Architecture</th>
                        </tr>
                    </thead>
                    <tbody>
                        {{#contents}}
                        <tr>
                            <td>{{file}}</td>
                            <td><a href="{{pkgname.path}}">{{pkgname.text}}</a></td>
                            <td>{{branch}}</td>
                            <td class="repo">
                                <a class="hint--right" aria-label="{{repo.title}}" href="?file={{args.file}}&path={{args.path}}&name={{args.name}}&branch={{args.branch}}&repo={{repo.text}}&arch={{args.arch}}">
                                    {{repo.text}}
                                </a>
                            </td>
                            <td class="arch">
                                <a class="hint--right" aria-label="{{arch.title}}" href="?file={{args.file}}&path={{args.path}}&name={{args.name}}&branch={{args.branch}}&repo={{args.repo}}&arch={{arch.text}}">
                                    {{arch.text}}
                                </a>
                            </td>
                        </tr>
                        {{/contents}}
                        {{^contents}}
                        <tr>
                            <td colspan="5">No item found...</td>
                        </tr>
                        {{/contents}}
                    </tbody>
                </table>
            </div>
            <div class="pure-menu pure-menu-horizontal" id="pagination">
                <nav>
                    <ul class="pure-menu-list">
                    {{#pager}}
                    <li class="pure-menu-item {{{class}}}"><a class="pure-menu-link" href="/contents?{{{args}}}">{{{page}}}</a></li>
                    {{/pager}}
                    </ul>
                </nav>
            </div>
        </main>
{{{footer}}}
