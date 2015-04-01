{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search the contents of packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="filename">File</label>
                        <input type="text" class="form-control" id="filename" name="filename" value="{{{filename}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="path">Path</label>
                        <input type="text" class="form-control" id="path" name="path" value="{{{path}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="pkgname">Package</label>
                        <input type="text" class="form-control" id="pkgname" name="pkgname" value="{{{pkgname}}}" placeholder="use % as wildcard">
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
                <table class="table table-striped table-bordered table-condensed" data-toggle="table">
                    <tr>
                        <th>File</th>
                        <th>Package name</th>
                        <th>Repository</th>
                        <th>Architecture</th>
                    </tr>{{#rows}}
                    <tr>
                        <td>{{{file}}}</td>
                        <td><a href="/package/{{{repo}}}/{{{arch}}}/{{{pkgname}}}">{{{pkgname}}}</a></td>
                        <td>{{{repo}}}</td>
                        <td>{{{arch}}}</td>
                    </tr>{{/rows}}
                    {{{^rows}}}
                    <tr>
                        <td colspan="4">No item found...</td>
                    </tr>
                    {{{/rows}}}
                </table>
            </div>
            <div class="panel-footer text-center">{{#pager}}
                <nav>
                    <ul class="pagination">{{/pager}}{{#pager}}{{#prev}}
                        <li class=""><a href="/contents?{{{prev}}}" aria-label="Previous"><span aria-hidden="true">&laquo;</span></a></li>{{/prev}}{{/pager}}{{#pager}}{{^prev}}
                        <li class="disabled"><a href="" aria-label="Previous"><span aria-hidden="true">&laquo;</span></a></li>{{/prev}}{{/pager}}{{#pager}}
                        <li class="active"><a href="#">{{{page}}}</a></li>{{/pager}}{{#pager}}{{#next}}
                        <li><a href="/contents?{{{next}}}" aria-label="Next"><span aria-hidden="true">&raquo;</span></a></li>{{/next}}{{/pager}}{{#pager}}{{^next}}
                        <li class="disabled"><a href="#" aria-label="Next"><span aria-hidden="true">&raquo;</span></a></li>{{/next}}{{/pager}}{{#pager}}
                    </ul>
                </nav>{{/pager}}
            </div>
        </div>
    </div>
{{{footer}}}
