{{{header}}}
    <script>$(document).ready(function(){$('[data-toggle="tooltip"]').tooltip({container: 'html'});});</script>
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search for flagged packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="package">Origin</label>
                        <input type="text" class="form-control" id="name" name="name" value="{{{form.name}}}" placeholder="use % as wildcard">
                    </div>
                    <div class="form-group">
                        <label for="repo">Repository</label>
                        <select name="repo" class="form-control" id="repo">
                        {{#form.repo}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.repo}}
                        </select>
                    </div>
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
            </div>
            <div class="table-responsive">
                <table class="table table-striped table-bordered table-condensed">
                    <tr>
                        <th>Origin</th>
                        <th>Repository</th>
                        <th>Version</th>
                        <th>Date</th>
                        <th>Message</th>
                    </tr>
                    {{#pkgs}}
                    <tr>
                        <td class="origin">
                            <a data-toggle="tooltip" title="{{{origin.title}}}" href="{{{origin.path}}}">{{{origin.text}}}</a>
                        </td>
                        <td class="repo">{{{repo}}}</td>
                        <td class="version text-danger"><strong>{{{version}}}</strong></td>
                        <td class="date">{{{date}}}</td>
                        <td class="message"><span class="glyphicon glyphicon-envelope" aria-hidden="true" title="{{message}}" data-toggle="tooltip"></span></td>
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