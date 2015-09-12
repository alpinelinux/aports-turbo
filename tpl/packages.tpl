{{{header}}}
    <script>
        $(document).ready(function(){
            $('[data-toggle="tooltip"]').tooltip({container: 'html'});
            $('.chosen-select').chosen();
        });
    </script>
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search for packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="package">Package name</label>
                        <input type="text" class="form-control" id="name" name="name" value="{{{form.name}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="repo">Repository</label>
                        <select name="repo" class="form-control chosen-select" id="repo">
                        {{#form.repo}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.repo}}
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="arch">Architecture</label>
                        <select name="arch" class="form-control chosen-select" id="arch">
                        {{#form.arch}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.arch}}
                        </select>
                    </div>
                    <div class="form-group">
                        <label for="maintainer">Maintainer</label>
                        <select name="maintainer" class="form-control chosen-select" id="maintainer">
                        {{#form.maintainer}}
                            <option {{{selected}}} value="{{{value}}}">{{{text}}}</option>
                        {{/form.maintainer}}
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
                    </tr>
                    {{#pkgs}}
                    <tr>
                        <td class="package">
                            <a data-toggle="tooltip" title="{{{name.title}}}" href="{{{name.path}}}">{{{name.text}}}</a>
                        </td>
                        {{#flagged}}
                        <td class="version">
                            <strong>
                                <a class="text-danger" href="#" data-toggle="tooltip" title="Flagged: {{{flagged.date}}}">{{{version.text}}}</a>
                            </strong>
                        </td>
                        {{/flagged}}
                        {{^flagged}}
                        <td class="version">
                            <strong>
                                <a class="text-success" href="{{{version.path}}}" data-toggle="tooltip" title="{{{version.title}}}">{{{version.text}}}</a>
                            </strong>
                        </td>
                        {{/flagged}}
                        <td class="url"><a href="{{{url.path}}}">{{{url.text}}}</a></td>
                        <td class="license">{{{license}}}</td>
                        <td class="arch">{{{arch}}}</td>
                        <td class="repo">{{{repo}}}</td>
                        <td class="maintainer">{{{maintainer}}}</td>
                        <td class="bdate">{{{build_time}}}</td>
                    </tr>
                    {{/pkgs}}
                    {{^pkgs}}
                    <tr>
                        <td colspan="8">No item found...</td>
                    </tr>
                    {{/pkgs}}
                </table>
            </div>
            <div class="panel-footer text-center">
                <nav>
                    <ul class="pagination">
                    {{#pager}}
                    <li class="{{{class}}}"><a href="/packages?{{{args}}}">{{{page}}}</a></li>
                     {{/pager}}
                    </ul>
                </nav>
            </div>
        </div>
    </div>
{{{footer}}}
