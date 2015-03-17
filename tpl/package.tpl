{{{header}}}
    <div id="main">
        <div class="panel panel-default">
            <div class="panel-heading">Package details</div>
            <div class="panel-body">
            </div>
            <table class="table table-striped table-bordered table-condensed" id="package">{{#name}}
                <tr>
                    <th>Name:</th>
                    <td title="{{{desc}}}"><a href="/package/{{{name}}}">{{{name}}}</a></td>
                </tr>
                <tr>
                    <th>Version:</th>
                    <td>{{{version}}}</td>
                </tr>
                <tr>
                    <th>Description:</th>
                    <td>{{{desc}}}</td>
                </tr>
                <tr>
                    <th>Project:</th>
                    <td><a href="{{{url}}}">URL</a></td>
                </tr>
                <tr>
                    <th>Licence:</th>
                    <td>{{{lic}}}</td>
                </tr>
                <tr>
                    <th>Architecture:</th>
                    <td>{{{arch}}}</td>
                </tr>{{#deps}}
                <tr>
                    <th>Dependecies:</th>
                    <td>{{{deps}}}</td>
                </tr>{{/deps}}
                <tr>
                    <th>Checksum:</th>
                    <td>{{{csum}}}</td>
                </tr>
                <tr>
                    <th>Size:</th>
                    <td>{{{size}}}</td>
                </tr>{{#install_size}}
                <tr>
                    <th>Installed size:</th>
                    <td>{{{install_size}}}</td>
                </tr>{{/install_size}}{{#provides}}
                <tr>
                    <th>Provides:</th>
                    <td>{{{provides}}}</td>
                </tr>{{/provides}}{{#install_if}}
                <tr>
                    <th>Install if:</th>
                    <td>{{{install_if}}}</td>
                </tr>{{/install_if}}
                <tr>
                    <th>Origin:</th>
                    <td>{{{origin}}}</td>
                </tr>
                <tr>
                    <th>Maintainer:</th>
                    <td>{{{maintainer}}}</td>
                </tr>
                <tr>
                    <th>Build time:</th>
                    <td>{{{build_time}}}</td>
                </tr>
                <tr>
                    <th>Commit:</th>
                    <td>{{{commit}}}</td>
                </tr>{{/name}}{{^name}}
                <tr>
                    <td>This package does not exist!</td>
                </tr>{{/name}}
            </table>
        </div>
    </div>
{{{footer}}}
