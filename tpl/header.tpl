<!DOCTYPE html>
<html lang="en">
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Alpine packages</title>
        <!-- Bootstrap -->
        <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.2/css/bootstrap.min.css">
        <link rel="stylesheet" href="/assets/style.css">
        <link rel="shortcut icon" href="/assets/favicon.ico" />
        
        <script src="//ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
        <script src="//maxcdn.bootstrapcdn.com/bootstrap/3.3.2/js/bootstrap.min.js"></script>

        <!-- HTML5 shim and Respond.js for IE8 support of HTML5 elements and media queries -->
        <!-- WARNING: Respond.js doesn't work if you view the page via file:// -->
        <!--[if lt IE 9]>
            <script src="https://oss.maxcdn.com/html5shiv/3.7.2/html5shiv.min.js"></script>
            <script src="https://oss.maxcdn.com/respond/1.4.2/respond.min.js"></script>
        <![endif]-->
    </head>
    <body>
    <header>
        <a href="/"><img id="logo" src="/assets/alpinelinux-logo.svg" alt="Alpine Linux logo" /></a>
        <div id="pagenav">
            <nav>
                <a href="/packages" class="{{nav.package}}" >Packages</a>
                <a href="/contents" class="{{nav.content}}" >Contents</a>
            </nav>
        </div>
        <div id="sitenav">
            <nav>
                <a href="http://wiki.alpinelinux.org">wiki</a>
                <a href="http://git.alpinelinux.org">git</a>
                <a href="http://bugs.alpinelinux.org/projects/alpine/issues">bugs</a>
                <a href="http://forum.alpinelinux.org/forum">forums</a>
            </nav>
        </div>
    </header>{{#alert}}
    <div class="alert alert-{{{type}}} alert-dismissible" role="alert" style="margin-top: 20px;">
        <button type="button" class="close" data-dismiss="alert" aria-label="Close"><span aria-hidden="true">&times;</span></button>
        {{{msg}}}
    </div>{{/alert}}
