{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search the contents of packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="filename">Filename</label>
                        <input type="text" class="form-control" id="filename" name="filename" value="{{{filename}}}">
                    </div>
                    <div class="form-group">
                        <label for="arch">Architecture</label>
                        <select name="arch" class="form-control" id="arch">
                            <option {{#x86}}selected{{/x86}} >x86</option>
                            <option {{#x86_64}}selected{{/x86_64}} >x86_64</option>
                            <option {{#armhf}}selected{{/armhf}} >armhf</option>
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
                        <td>{{{pkgname}}}</td>
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
        </div>
    </div>
{{{footer}}}
