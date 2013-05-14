use JSON qw/encode_json decode_json/;
use Data::Dumper;
open(ins, "<", "gen/decl.json");
open(ous, ">", "include/gen_token.hpp");
my $json_data;
foreach (<ins>) {
	$json_data .= $_;
}
my $data = decode_json($json_data);
my @array = @{$data};
my @token_enum = ();
my @kind_enum = ();
foreach my $elem (@array) {
	my $type = $elem->{type};
	my $kind = $elem->{kind};
	unless (grep{$_ eq $type} @token_enum) {
		push(@token_enum, $type);
	}
	unless (grep{$_ eq $kind} @kind_enum) {
		push(@kind_enum, $kind) if ($kind);
	}
}

print ous "namespace Enum {\n";
print ous "namespace Token {\n";
print ous "namespace Type {\n";
print ous "typedef enum {\n";
foreach (@token_enum) {
	print ous "\t$_,\n";
}
print ous "} Type;\n";
print ous "}\n";
print ous "\n";

print ous "namespace Kind {\n";
print ous "typedef enum {\n";
foreach (@kind_enum) {
	print ous "\t$_,\n";
}
print ous "} Kind;\n";
print ous "}\n";

print ous "}\n";
print ous "}\n";

open(ous, ">", "gen_token_decl.cpp");
print ous "#include <common.hpp>\n";
print ous "TokenInfo decl_tokens[] = {\n";
foreach my $elem (@array) {
    my $type = $elem->{type};
    my $kind = $elem->{kind};
    my $data = $elem->{data};
    print ous "\t{Enum::Token::Type::${type}, Enum::Token::Kind::${kind}, \"${type}\", \"${data}\"},\n";
}
print ous "};\n";
print ous "\n";

open(ous, ">", "lib/Compiler/Lexer/Constants.pm");
my $token_type_enums = "";
my $count = 0;
foreach my $tk (@token_enum) {
    $token_type_enums .= " " x 4 . "T_$tk => $count,\n";
    $count++;
}

my $kind_enums = "";
$count = 0;
foreach my $kind (@kind_enum) {
    $kind_enums .= " " x 4 . "T_$kind => $count,\n";
    $count++;
}

print ous <<CODE;
package Compiler::Lexer::TokenType;
use strict;
use warnings;
use constant {
$token_type_enums
};
1;

package Compiler::Lexer::SyntaxType;
use strict;
use warnings;
use constant {
    T_Value     => 0,
    T_Term      => 1,
    T_Expr      => 2,
    T_Stmt      => 3,
    T_BlockStmt => 4
};
1;

package Compiler::Lexer::Kind;
use strict;
use warnings;
use constant {
$kind_enums
};
1;
CODE
close(ous);
