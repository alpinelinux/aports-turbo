{{{header}}}
    <script>
        $(document).ready(function(){
            $('[data-toggle="tooltip"]').tooltip({container: 'html'});
            $('.chosen-select').chosen({allow_single_deselect: true});
        });
    </script>
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search the contents of packages</div>
            <div class="panel-body">
                <form role="form" id="search" class="form-inline">
                    <div class="form-group">
                        <div class="input-group">
                            <input type="text" class="form-control" id="file" name="file" value="{{{form.file}}}" placeholder="File" autofocus>
                            <span data-toggle="tooltip" class="input-group-addon cursor-pointer" title="Use * and ? as wildcards">?</span>
                        </div>
                    </div>
                    <div class="form-group">
                        <div class="input-group">
                            <input type="text" class="form-control" id="path" name="path" value="{{{form.path}}}" placeholder="Path">
                            <span data-toggle="tooltip" class="input-group-addon cursor-pointer" title="Use * and ? as wildcards">?</span>
                        </div>
                    </div>
                    <div class="form-group">
                        <div class="input-group">
                            <input type="text" class="form-control" id="name" name="name" value="{{{form.name}}}" placeholder="Package">
                            <span data-toggle="tooltip" class="input-group-addon cursor-pointer" title="Use * and ? as wildcards">?</span>
                        </div>
                    </div>
                    <div class="form-group">
                        <select name="branch" data-placeholder="Branch" class="form-control chosen-select" id="branch" >
                        {{#form.branch}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.branch}}
                        </select>
                    </div>
                    <div class="form-group">
                        <select name="repo" data-placeholder="Repo" class="form-control chosen-select" id="repo">
                        {{#form.repo}}
                            <option {{{selected}}} >{{{text}}}</option>
                        {{/form.repo}}
                        </select>
                    </div>
                    <div class="form-group">
                        <select name="arch" data-placeholder="Arch" class="form-control chosen-select" id="arch">
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
                        <th>Package</th>
                        <th>Branch</th>
                        <th>Repository</th>
                        <th>Architecture</th>
                    </tr>
                    {{#contents}}
                    <tr>
                        <td>{{{file}}}</td>
                        <td><a href="{{{pkgname.path}}}">{{{pkgname.text}}}</a></td>
                        <td>{{{branch}}}</td>
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
