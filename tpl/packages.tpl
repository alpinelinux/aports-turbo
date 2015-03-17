{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Search for packages</div>
            <div class="panel-body">
                <form class="form-inline" role="form" id="search">
                    <div class="form-group">
                        <label for="package">Package name</label>
                        <input type="text" class="form-control" id="package" name="package" value="{{{package}}}">
                    </div>
	                <div class="form-group">
                        <label for="arch">Architecture</label>
	                    <select name="arch" class="form-control" id="arch">
                            <option>x86</option>
                            <option>x86_64</option>
                            <option>armhf</option>
                        </select>
	                </div>
                    <button type="submit" class="btn btn-primary">Search</button>
                </form>
            </div>
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
    </div>
{{{footer}}}
