{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search the contents of packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="filename">File</label>
                        <input type="text" class="form-control" id="filename" name="filename" value="{{{form.filename}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="path">Path</label>
                        <input type="text" class="form-control" id="path" name="path" value="{{{form.path}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="package">Package</label>
                        <input type="text" class="form-control" id="pkgname" name="pkgname" value="{{{form.name}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="repo">Repo</label>
                        <select name="repo" class="form-control" id="repo">
                        {{#form.repo}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.repo}}
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="arch">Arch</label>
                        <select name="arch" class="form-control" id="arch">
                        {{#form.arch}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.arch}}
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
                    </tr>
                    {{#contents}}
                    <tr>
                        <td>{{{file}}}</td>
                        <td><a href="{{{pkgname.patch}}}">{{{pkgname.text}}}</a></td>
                        <td>{{{repo}}}</td>
                        <td>{{{arch}}}</td>
                    </tr>
                    {{/contents}}
                    {{^contents}}
                    <tr>
                        <td colspan="4">No item found...</td>
                    </tr>
                    {{/contents}}
                </table>
            </div>
            <div class="panel-footer text-center">
                <nav>
                    <ul class="pagination">
                    {{#pager}}
                    <li class="{{{class}}}"><a href="/contents?{{{args}}}">{{{page}}}</a></li>
                     {{/pager}}
                    </ul>
                </nav>
            </div>
        </div>
    </div>
{{{footer}}}
