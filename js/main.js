var app = angular.module('ngApp', ['ui.bootstrap', 'ui.ace']);

app.controller('ngController', [ '$scope', function($scope) {

    $scope.keyboardMode = "ace/keyboard/emacs";

    $scope.$watch('keyboardMode', function() {
        $scope.editor.setKeyboardHandler($scope.keyboardMode);
    });
    
    $scope.aceLoaded = function(editor) {
        $scope.editor = editor;
        editor.getSession().setMode("ace/mode/perl");
        editor.setTheme("ace/theme/cobalt");
    };
    
    $scope.aceChanged = function(e) {
        var source = $scope.editor.getSession().getValue();
        var tokens = Module.tokenize(source);
        var size   = tokens.size();
        $scope.tokens = [];
        for (var i = 0; i < size; i++) {
            var token = tokens.get(i);
            $scope.tokens.push({
                "name" : token.getName(),
                "data" : token.getData()
            });
        }
    };

    $scope.synopsisLoaded = function(editor) {
        editor.setOptions({
            readOnly: true,
            highlightActiveLine: false,
            showGutter: false
        });
        editor.setFontSize(16);
        editor.getSession().setMode("ace/mode/perl");
        editor.setTheme("ace/theme/xcode");
    };

    $scope.howToInstallLoaded = function(editor) {
        editor.setOptions({
            readOnly: true,
            highlightActiveLine: false,
            showGutter: false
        });
        editor.setFontSize(16);
        editor.getSession().setMode("ace/mode/shell");
        editor.setTheme("ace/theme/terminal");
    };

}]);
