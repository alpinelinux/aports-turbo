{{{header}}}
    <script>
        $(document).ready(function(){
            $('[data-toggle="tooltip"]').tooltip({container: 'html'});
            $('.chosen-select').chosen({allow_single_deselect: true});
            $('[data-toggle="popover"]').popover();
        });
    </script>
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search for packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <div class="input-group">
                            <input type="text" class="form-control" id="origin" name="origin" value="{{form.origin}}" placeholder="Origin" autofocus>
                            <span data-toggle="tooltip" class="input-group-addon cursor-pointer" title="Use * and ? as wildcards">?</span>
                        </div>
                    </div>
                    <div class="form-group">
                        <select name="repo" data-placeholder="Repository" class="form-control chosen-select" id="repo">
                        {{#form.repo}}
                            <option {{{selected}}} >{{text}}</option>
                        {{/form.repo}}
                        </select>
                    </div>
                    <div class="form-group">
                        <select name="maintainer" data-placeholder="Maintainer" class="form-control chosen-select" id="maintainer">
                        {{#form.maintainer}}
                            <option {{{selected}}} >{{text}}</option>
                        {{/form.maintainer}}
                        </select>
                    </div>
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
            </div>
            <div class="table-responsive">
                <table class="table table-striped table-bordered table-condensed">
                    <tr>
                        <th>Origin</th>
                        <th>Version</th>
                        <th>New version</th>
                        <th>Repository</th>
                        <th>Maintainer</th>
                        <th>Flag date</th>
                        <th>Message</th>
                    </tr>
                    {{#pkgs}}
                    <tr>
                        <td class="package">
                            <a data-toggle="tooltip" title="{{origin.title}}" href="{{origin.path}}">{{origin.text}}</a>
                        </td>
                        <td class="version text-danger"><strong>{{version}}</strong></td>
                        <td class="new_version">{{new_version}}</td>
                        <td class="repo">{{repo}}</td>
                        <td class="maintainer">{{maintainer}}</td>
                        <td class="created">{{created}}</td>
                        <td class="message text-center">
                            <a class="text-muted" href="#" title="Message" data-toggle="popover" data-container="body" data-placement="left" data-trigger="click" data-content="{{message}}">
                                <span class="glyphicon glyphicon-comment"></span>
                            </a>
                        </td>
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
                    <li class="{{{class}}}"><a href="/flagged?{{{args}}}">{{{page}}}</a></li>
                    {{/pager}}
                    </ul>
                </nav>
            </div>
        </div>
    </div>
{{{footer}}}
