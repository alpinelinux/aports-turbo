{{{header}}}
        <main id="flagged">
            <div class="grid-head">Flagged filter</div>
            <div class="grid-body" id="search-form">
                <div class="pure-g">
                    <div class="pure-u-1">
                        <form class="pure-form pure-form-stacked">
                            <div class="pure-g">
                                <div class="pure-u-1 pure-u-md-4-24 form-field hint--top" aria-label="Use * and ? as wildcards">
                                        <input class="pure-input-1" type="text" id="origin" name="origin" value="{{form.origin}}" placeholder="Origin" autofocus>
                                </div>
                                <div class="pure-u-1 pure-u-md-2-24 form-field">
                                    <select class="pure-input-1" name="repo" id="repo">
                                        <option value="" disabled {{form.placeholder.repo}}>Repository</option>
                                    {{#form.repo}}
                                        <option {{{selected}}}>{{text}}</option>
                                    {{/form.repo}}
                                    </select>
                                </div>
                                <div class="pure-u-1 pure-u-md-5-24 form-field">
                                    <select class="pure-input-1" name="maintainer" id="maintainer">
                                        <option value="" disabled {{form.placeholder.maintainer}}>Maintainer</option>
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
                            <th>Origin</th>
                            <th>Version</th>
                            <th>New version</th>
                            <th>Repository</th>
                            <th>Maintainer</th>
                            <th>Flag date</th>
                            <th>Message</th>
                        </tr>
                    </thead>
                    <tbody>
                        {{#pkgs}}
                        <tr>
                            <td class="package"><a href="{{origin.path}}">{{origin.text}}</a></td>
                            <td class="version text-danger"><strong>{{version}}</strong></td>
                            <td class="new_version">{{new_version}}</td>
                            <td class="repo">
                                <a class="hint--right" aria-label="{{repo.title}}" href="?origin={{args.origin}}&repo={{repo.text}}&maintainer={{args.maintainer}}">
                                    {{repo.text}}
                                </a>
                            </td>
                            <td class="maintainer">
                                <a class="hint--right" aria-label="{{maintainer.title}}" href="?origin={{args.origin}}&repo={{args.repo}}&maintainer={{maintainer.text}}">
                                    {{maintainer.text}}
                                </a>
                            </td>
                            <td class="created">{{created}}</td>
                            <td class="message">
                                <div class="{{class}}" aria-label="{{message}}">
                                    <img src="/assets/comment.svg" alt="comment">
                                </div>
                            </td>
                        </tr>
                        {{/pkgs}}
                        {{^pkgs}}
                        <tr>
                            <td colspan="7">No item found...</td>
                        </tr>
                        {{/pkgs}}
                    </tbody>
                </table>
            </div>
            <div class="pure-menu pure-menu-horizontal" id="pagination">
                <nav>
                    <ul class="pure-menu-list">
                    {{#pager}}
                    <li class="pure-menu-item {{{class}}}">
                        <a class="pure-menu-link" href="/flagged?{{{args}}}">{{{page}}}</a>
                    </li>
                    {{/pager}}
                    </ul>
                </nav>
            </div>
        </main>
{{{footer}}}
