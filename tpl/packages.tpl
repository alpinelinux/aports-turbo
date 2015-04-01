{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search for packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="package">Package name</label>
                        <input type="text" class="form-control" id="package" name="package" value="{{{package}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="repo">Repository</label>
                        <select name="repo" class="form-control" id="repo">
                            <option{{{#all}}} selected {{{/all}}}>all</option>
                            <option{{{#main}}} selected {{{/main}}}>main</option>
                            <option{{{#testing}}} selected {{{/testing}}}>testing</option>
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="arch">Architecture</label>
                        <select name="arch" class="form-control" id="arch">
                            <option{{#x86}} selected {{/x86}}>x86</option>
                            <option{{#x86_64}} selected {{/x86_64}}>x86_64</option>
                            <option{{#armhf}} selected {{/armhf}}>armhf</option>
                        </select>
                    </div>
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
            </div>
            <div class="table-responsive">
                <table class="table table-striped table-bordered table-condensed">
                    <tr>
                        <th>Package</th>
                        <th>Version</th>
                        <th>Project</th>
                        <th>Licence</th>
                        <th>Architecture</th>
                        <th>Repository</th>
                        <th>Maintainer</th>
                        <th>Build date</th>
                    </tr>{{#rows}}
                    <tr>
                        <td class="package" title="{{{desc}}}"><a href="/package/{{{arch}}}/{{{package}}}">{{{package}}}</a></td>
                        <td class="version">{{{version}}}</td>
                        <td class="url"><a href="{{{project}}}">URL</a></td>
                        <td class="license">{{{license}}}</td>
                        <td class="arch">{{{arch}}}</td>
                        <td class="repo">{{{repo}}}</td>
                        <td class="maintainer">{{{maintainer}}}</td>
                        <td class="bdate">{{{bdate}}}</td>
                    </tr>{{/rows}}
                    {{{^rows}}}
                    <tr>
                        <td colspan="8">No item found...</td>
                    </tr>
                    {{{/rows}}}
                </table>
            </div>
            <div class="panel-footer text-center">{{#pager}}
                <nav>
                    <ul class="pagination">{{/pager}}{{#pager}}{{#prev}}
                        <li class=""><a href="/packages?{{{prev}}}" aria-label="Previous"><span aria-hidden="true">&laquo;</span></a></li>{{/prev}}{{/pager}}{{#pager}}{{^prev}}
                        <li class="disabled"><a href="" aria-label="Previous"><span aria-hidden="true">&laquo;</span></a></li>{{/prev}}{{/pager}}{{#pager}}
                        <li class="active"><a href="#">{{{page}}}</a></li>{{/pager}}{{#pager}}{{#next}}
                        <li><a href="/packages?{{{next}}}" aria-label="Next"><span aria-hidden="true">&raquo;</span></a></li>{{/next}}{{/pager}}{{#pager}}{{^next}}
                        <li class="disabled"><a href="#" aria-label="Next"><span aria-hidden="true">&raquo;</span></a></li>{{/next}}{{/pager}}{{#pager}}
                    </ul>
                </nav>{{/pager}}
            </div>
        </div>
    </div>
{{{footer}}}
