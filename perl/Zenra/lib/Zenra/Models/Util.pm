package Zenra::Models::Util;
use Any::Moose;
use Zenra::Models;
use Encode qw/encode_utf8 decode_utf8/;

has zenra => (
    is  => 'ro',
    isa => 'Str',
    default => sub { '全裸で' },
);

sub zenrize {
    my ($self, $text) = @_;

    # 既に含まれていればそれ以上何もしない
    return $text if $self->zenrized($text);

    $text = encode_utf8 $text;
    my $result = '';
    for my $sentence (split/(\s+)/, $text) {
        $result .= $sentence =~ /\s+/ ? $sentence : $self->_zenrize($sentence);
    }

    return decode_utf8 $result;
}

sub zenrized {
    my ($self, $text) = @_;

    return $text =~ decode_utf8 $self->zenra;
}

# 日本語の文章を全裸にする
sub _zenrize {
    my ($self, $sentence) = @_;

    my $result = '';
    my $n = models('mecab')->parse($sentence);

    # 末尾まで進める
    $n = $n->next while ($n->next);

    my $flg = 0;
    # 末尾からさかのぼる
    while (($n = $n->prev)->prev) {
        # フラグがたっていれば「全裸で」を挿入
        # ただし、名詞／副詞／動詞のときはまだ挿入しない
        if ($flg) {
            my $insert = 1;
            if ($n->feature =~ / \A (名詞|副詞|動詞) /xms) {
                $insert = 0;
            }
            # また、連用形の動詞→助(動)詞の場合も挿入しない
            elsif ($n->feature =~ / \A 助(動)?詞 /xms &&
                       (split(/,/, $n->prev->feature))[5] =~ / 連用 /xms) {
                $insert = 0;
            }
            if ($insert) {
                $result = $self->zenra . $result;
                $flg = 0;
            }
        }
        # 出力の連結
        $result = $n->surface . $result;
        # 動詞を検出してフラグをたてる
        if ($n->feature =~ / \A 動詞 /xms) {
            $flg = 1;
        }
    }
    # 先頭のチェック
    if ($flg) {
        $result = $self->zenra . $result;
    }

    return $result;
}

__PACKAGE__->meta->make_immutable;
